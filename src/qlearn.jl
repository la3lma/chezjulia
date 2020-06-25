###
###  Q learning experiments
###



##
##  One-hot coding of game state and moves.
##

using Flux
using Flux: onehot, onecold

one_hot_encode_coordinate_pair(source::Coord, destination::Coord) =
    transpose(vcat(onehot(source,      all_chessboard_locations),
                   onehot(destination, all_chessboard_locations)))

@test length(one_hot_encode_coordinate_pair(Coord(1,1), Coord(2,2))) == 128

one_hot_encode_move(m::Move) = one_hot_encode_coordinate_pair(m.start, m.destination)

one_hot_encode_piece(p::ChessPiece) = onehot(p, all_chess_pieces)

function one_hot_encode_board(board::ChessBoard)
    nested_vector = [one_hot_encode_piece(get_piece_at(board, location)) for location in all_chessboard_locations]
    return reshape(collect(Iterators.flatten(nested_vector)), (1, 832))
end

@test length(one_hot_encode_board(startingBoard)) ==  (13 * 64)


one_hot_encode_chess_state(state, move_being_queried, action_history = nothing , state_history = nothing) =
     collect(Iterators.flatten([one_hot_encode_board(state), one_hot_encode_move(move_being_queried)]))


@test length(one_hot_encode_chess_state(startingBoard, Move(Coord(1,1), Coord(2,2), false, bp, bp))) == 960



###
###  Q-learning mechanics
###



mutable struct Q_learning_state
    chain
    cache::Dict
    randomness::Float64
end

function wipe_cache!(qs::Q_learning_state)
    for k  in keys(qs.cache)
        delete!(qs.cache, k)
    end
end


###
### Storing and restoring q players' weights
###
using BSON: @save
using BSON: @load


## TODO: Check if GPU is being used, and if it is, then transform
##       chain to/from CPU before/after writing/writing.

function store_q_player(p, name)
    @save "$name.bson" p
end


function restore_q_player(name)
    filename = "$name.bson"
    if isfile(filename)
        @load filename p
        strategy = new_q_choice(p.state)
        p = Player(p.id, strategy, p.state)
        return p
    else
        return Nothing
    end
end



##
## Store/restore clone generation number
##


function store_int(arg, filename)
    open(filename, "w") do io
        write(io, "$arg\n")
    end    
end

function restore_int(filename)
    if isfile(filename)
        open(filename, "r") do io
            l = readline(io)
            return parse(Int, l)
        end
    else
        return Nothing
    end
end



clone_generation_filename="clone_generation.txt"
store_clone_generation(clone_generation) = store_int(clone_generation, clone_generation_filename)
restore_clone_generation() = restore_int(clone_generation_filename)


learning_round_filename="learning_round.txt"
store_learning_round(round) = store_int(round, learning_round_filename)
restore_learning_round() = restore_int(learning_round_filename)



##
##  One-hot coding of Q-values
##

no_of_output_nodes_to_encode_q=100

function one_hot_encode_q(x)
    @assert (x >= -1) "$x >= -1 failed"
    @assert (x <=  1) "$x <=  1 failed"
    idx = trunc(Int, no_of_output_nodes_to_encode_q * (x+1)/2)
    @assert(idx > 0)
    @assert(idx <= no_of_output_nodes_to_encode_q)
    result = zeros(Bool, no_of_output_nodes_to_encode_q)
    result[idx] = 1
    r = permutedims(result)
    return r
end

function one_cold_decode_q(x)
    decode_index(i::CartesianIndex) = i[2]
    decode_index(i::Int) = i
    idx = argmax(x)
    idx = decode_index(idx)
    return  2*(idx/no_of_output_nodes_to_encode_q) - 1
end

@test one_cold_decode_q(one_hot_encode_q(0.0)) == 0.0


function raw_q_lookup(qs::Q_learning_state, encoded_statemove)
    if haskey(qs.cache, encoded_statemove)
        return qs.cache[encoded_statemove]
    else
        result = one_cold_decode_q(qs.chain(encoded_statemove))
        qs.cache[encoded_statemove] = result
        return result
    end
end

get_q_value(qs, state, move, action_history, state_history) =
    raw_q_lookup(qs, one_hot_encode_chess_state(state, move))


# Find the maximm value in the sequence, then return
# One of the indexes that contains that value
function randomized_argmax(sequence)
    (max_value, first_max_index) = findmax(sequence)
    # Is sufficiently close to max
    is_max(x) = abs(x - max_value) < 0.000000001
    return findall(is_max, sequence) |> get_random_element
end

@test randomized_argmax([0; 0; 2; 3; 3; 2; 1]) >= 3
@test randomized_argmax([0; 0; 2; 3; 3; 2; 1]) <= 5

function new_q_choice(qs::Q_learning_state)

    # Generate a new choice based on the evaluation in the network ("chain") in the
    # qs learning state.
    function get_q_choice(state,  available_moves, action_history, state_history)
        get_q = move -> get_q_value(qs, state, move, action_history, state_history)
        if qs.randomness > rand()
            return get_random_element(available_moves)
        else            
            best_move_index = randomized_argmax(map(get_q, available_moves))
            return available_moves[best_move_index]
        end
    end

    return get_q_choice
end


##
## Calculate the rewards from winnings and draws
##

reward(x::Draw, color::Color) = 0
reward(x::Win, color::Color)  = (x.winner == color) ? 1 : -1


deconstruct_episode(r::Game_Result) = (r.outcome, r.move_history, r.board_history)


# Calulate what the Q-values should be based on the old q_values
# that are present in qs, and present them as a
# set of learning tuples, that can be interpreted as a
# learning set for the qs.chain network


function learn_from_episode(qs, episode)

    q_old(encoded_statemove) = raw_q_lookup(qs, encoded_statemove)


    # Destructuring!
    outcome, move_history, board_history = deconstruct_episode(episode)

    episode_length = length(move_history)

    learning_tuples = []
    future_value_estimate = 0

    # Impact on first position
    impact1 = 1/episode_length

    #discount_factor (0 < 𝛾 <= 1)
    #  ... the discount factor is tuned soo that the
    # the impact isn't  too small
    𝛾 = (1/episode_length)^(1/episode_length)

    # println("𝛾 = $𝛾")

    # learning rate (0 < ɑ <= 1)
    𝛼 = 0.3

    for t in episode_length:-1:1

        move   = move_history[t]
        board  = board_history[t]
        color  = get_piece_at(board, move.start).color # color == player, in chess.  Need to generalize that.
        r      = t != episode_length ? 0 : reward(outcome, color)
        esm    = one_hot_encode_chess_state(board, move)

        # Basic Q-learning formula
        new_q = q_old(esm) + 𝛼 * (r + 𝛾 * future_value_estimate)

        # Since this is an adversarial game, every other
        # round we need to flip the value estimate's sign
        future_value_estimate = - new_q
        # Kludge to avoid the q value going above 1 (which may or may not
        # be very important to do.

        q_to_encode = 2*sigmoid(new_q) - 1
        #    println("Episode $t has q to encode = $q_to_encode")

        onehot_q = one_hot_encode_q(q_to_encode)
        learning_tuple = [esm, onehot_q]
        push!(learning_tuples, learning_tuple)
    end
    return learning_tuples
end


function one_hot_coded_q_values_difference(q1,q2)
    v1 = one_cold_decode_q(q1)
    v2 = one_cold_decode_q(q2)
    return v1 - v2
end

function q_learn!(qs, episodes)
    wipe_cache!(qs)

    println("Q-learning")

    learning_episodes = map(episode -> learn_from_episode(qs, episode), episodes)

    learning_episodes = todevice(learning_episodes)

    chain = qs.chain |> gpu
    learning_episodes = learning_episodes |> gpu

    ## Don't really knwo how to set up the loss function
    # loss(x, y) = Flux.mse(chain(x), y)
    #  ... the value below is failing!
    # loss(x, y) = one_hot_coded_q_values_difference(chain(x), y)
    loss(x,y) = Flux.crossentropy(chain(x),y)
    
    ps = Flux.params(chain)
    opt =  ADAM() # uses the default η = 0.001 and β = (0.9, 0.999)

    print("   Training: ")
    for episode in learning_episodes
        print(".")
        Flux.train!(loss, ps, episode, opt)
    end

    qs.chain = chain |> cpu
    println()
end

use_gpu = true
todevice(x) = use_gpu ? gpu(x) : x


##
##   Running the Q-learning mechanism
##



## XXX The chain being  used here is just made  up at the spur of the moment.
##     it needs to be properly engineered and tuned. Right now it's just
##     a placeholder to get the rest of the machinery in place.

new_q_chain() =
    Chain(
        Dense(960, 960, relu),
        Dense(960, 400, relu),
        Dense(400, 200, relu),
        Dense(200, 200, relu),
        Dense(200, 200, relu),
        Dense(200, 200, relu),
        Dense(200, 200, relu),
        Dense(200, 200, relu),
        Dense(200, 200, relu),
        Dense(200, no_of_output_nodes_to_encode_q),
        softmax)

new_q_state(chain  = new_q_chain(), randomness::Float64 = 0) =
    Q_learning_state(
        chain,
        Dict{Array{Bool,1},Float32}(),
        randomness)


###
###  Next generation tournament-based players
###  (when this works, refactor much of the code above into oblivion)
###

function new_q_player(name, randomness)
    qs = new_q_state(new_q_chain(), randomness)
    strategy = new_q_choice(qs)
    return Player(name, strategy, qs)
end

clone_q_state(qs, clone_randomness::Bool = false) =
    Q_learning_state(deepcopy(qs.chain), Dict{Array{Bool,1},Float32}(), clone_randomness ? qs.randomness : 0.0)

function clone_q_player(name, qp)
    qs = clone_q_state(qp.state)
    strategy = new_q_choice(qs)
    return Player(name, strategy, qs)
end

function q_learn_tournament_result!(learning_player, tournament_result)
    q_learn!(learning_player.state,  tournament_result.games)
end



##
##  Tournament learning.  Starting with one random player and
##  one learning player.  Until the required number of tournaments has
##  been run, play the players against each other. Let the learning player
##  learn until it beats the non-learning player in 55% or more of the
##  games in the tournament.  At that point clone the learning player
##  and let it continue the tournament learning by playing against a non-learning
##  clone of itself.   This way the learning player will always be matched
##  be an equally good, or almost as good player as itself is.
##
function tournament_learning(
    no_of_tournament_rounds::Int64=100,
    cloning_trigger = 0.55,
    max_rounds_in_tournament_games=200,
    tournament_length = 12,
    player_1 = Nothing,
    player_2 = Nothing,
    do_snapshots = false,
    clone_generation = Nothing,
    initial_tournament_round = Nothing)

    log = new_learning_log()


    if initial_tournament_round == Nothing
        initial_tournament_round = 1
    end
    
    if clone_generation == Nothing
        clone_generation = 1
    end

    force_clone_once = false
    
    if player_1 == Nothing
        force_clone_once = true
        player_1    =  new_q_player("Dummy q player",  0.05)
    end

    # When playing as a learning player, the q_player will
    # select 5% of its moves randomly among the currently available
    # moves.  This will put it at a disadvantage from a gameplay point of
    # view, but it will also explore more of the game space.  It's an
    # idea.  Don't know how to test it properly yet, but that is one of the
    # many things that should b e part of this experimental program in the end:
    # how to test settings of various hyperparameters and how they
    # influence system performance.

    if player_2 == Nothing
        player_2  = new_q_player("Initial q player",  0.05)
    end        
        
    # Using the random player to bootstrap here. Could equally well
    # have used an initial clone of the initial_q_player.
    (p1, p2) = (player_1, player_2)

    last_tournament_round = initial_tournament_round + no_of_tournament_rounds

    
    for tournament_round in initial_tournament_round:last_tournament_round

        # Play the tournament
        println("Playing tournament round $tournament_round ")
        tournament_result     = play_tournament(
            p1,
            p2,
            max_rounds_in_tournament_games,
            tournament_length)

        # Extract the values we need to log and progress
        p2_advantage = p2_win_ratio(tournament_result)
        p1name = p1.id
        p2name = p2.id
        cloning_triggered =  (p2_advantage >= cloning_trigger)

        # Log  the current learning round into a dataframe ("log")
        # so that we can keep track of progress.
        log_learning_round!(
            log,
            tournament_round,
            p1.id,
            p2.id,
            tournament_result.p1wins,
            tournament_result.p2wins,
            tournament_result.draws,
            p2_advantage,
            cloning_triggered,
            clone_generation)

        # If cloning was triggered, then do  that
        if cloning_triggered || force_clone_once
            force_clone_once = false
            clone_generation += 1
            clone = clone_q_player("Clone gen $clone_generation q-player", p2)
            (p1, p2) = (p2, clone) ## Or swap?   No semantic diffenence, but different naming.
        end

        # Then  learn from this round
        q_learn_tournament_result!(p2, tournament_result)
        if do_snapshots
            store_q_player(p1, "p1")
            store_q_player(p2, "p2")
            store_clone_generation(clone_generation)
            store_learning_round(tournament_round)
        end
    end

    # Finally return the dataframe with the log, and the
    # final evolved player
    return (log, p2)
end



run_big_tournament() = tournament_learning(
        20,     # no of tournaments
        0.55,   # Trigger
        200,    # Max rounds
        20)     # Tournament length


run_micro_tournament() = tournament_learning(
        5,     # no of tournaments
        0.55,   # Trigger
        200,    # Max rounds
        10)     # Tournament length

# Only useful for unit testing
run_nano_tournament() = tournament_learning(
        2,     # no of tournaments
        0.55,  # Trigger
        20,    # Max rounds
        5)     # Tournament length


@test run_nano_tournament != nothing


function learning_increment(prod=false)
    p1 = restore_q_player("p1")
    p2 = restore_q_player("p2")
    clone_generation = restore_clone_generation()
    learning_round = restore_learning_round()

    if learning_round != Nothing
        learning_round += 1
    end

    # TODO: Appending to the history is not happening in a proper manner!

    if prod
        tournament_learning(
            10,      # no of tournaments
            0.55,    # Trigger
            200,     # Max rounds
            100,     # Tournament length
            p1,      # First player
            p2,      # Second player
            true,    # Do snapshots
            clone_generation, # tssia
            learning_round
        )
    else
        tournament_learning(
            3,      # no of tournaments
            0.55,   # Trigger
            5,      # Max rounds
            2,      # Tournament length
            p1,     # First player
            p2,     # Second player
            true,   # Do snapshots
            clone_generation, # tssia
            learning_round
        )
    end
end
