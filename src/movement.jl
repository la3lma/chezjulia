
###
###  Representing movement
###


##
## Representing moves
##


# Representing moves
struct Move
    start:: Coord
    destination:: Coord
    capture:: Bool
    startPiece:: ChessPiece
    destinationPiece:: ChessPiece
end

captures_king(m::Move) = (m.destinationPiece.piecetype == king)

##
## Applying moves
##
function apply_move!(m::Move, board::ChessBoard)

    finish_line(color::Color)     =  (color == black) ? 1 : 8

    # New board
    cloned_board = clone_board(board)

    # Do queen conversion  if appropriate
    if (m.startPiece.piecetype == pawn && m.destination.y == finish_line(m.startPiece.color))
       piece_being_placed_at_destination = queen_of_color(m.startPiece.color)
    else
       piece_being_placed_at_destination = m.startPiece
    end

    # Do placement
    set_piece_at!(cloned_board, m.destination, piece_being_placed_at_destination)
    set_piece_at!(cloned_board, m.start, bs)

    return cloned_board
end


##
## Pretty printing moves
##

# Take a look at http://en.wikipedia.org/wiki/Chess_notation, Print moves
# in an orderly proficient algebraic or long algebraic manner.

# The two implementations below are not really conformant

# Standard Algebraic Notation (SAN)
function move_as_san(m::Move)::String
    capture = m.capture ? "x" : ""
    return @sprintf("%s%s%s%s", m.startPiece.printrep, m.start, capture, m.destination)
end

# Figurine Algebraic Notation (FAN)
function move_as_san(m::Move)::String
    capture = m.capture ? "x" : ""
    return @sprintf("%s%s%s%s", m.startPiece.unicode, m.start, capture, m.destination)
end


show(io::IO, m::Move) = show(io, move_as_san(m))


##
## Checking if moves are identical.  May be of interest when looking for
## draws due to multiple repetitions of moves.
##
#
# function ==(m1::Move, m2::Move)
#      return (m1.start == m2.start) &&
#             (m1.destination == m2.destination) &&
# 	    (m1.capture == m2.capture) &&
# 	    (m1.startPiece == m2.startPiece) &&
# 	    (m1.destinationPiece == m2.destinationPiece)
# end


##
##  Finding all valid moves, generic code
##

function get_all_coords()
    result = Coord[]
     for y = 1:8, x = 1:8
        c = Coord(x, y)
        push!(result, c)
     end
     return result
end

coords = get_all_coords()

@test 64 == length(coords)

# Get coordinates for all the pieces of a particular
# color, these coordinates will then be used to generate
# all possible moves for that color.
get_coords_for_pieces(color::Color, board::ChessBoard) = 
   return filter(c -> (get_piece_at(board, c).color == color), coords)


#  Given an iterable of moves, will filter out anything that is not
#  a valid move, either because it's a nothing object, or because
#  the endpoint coordinate is out of bounds.
function valid_moves(moves)
    move_is_valid(::Nothing) = false
    move_is_valid(m::Move)   = isValidCoord(m.destination)

    return  filter(move_is_valid, moves)
end


# Starting with a piece at the start coordinate, moving that
# piece using the jump offset generates s candidate move.
# If the target is a valid coordinate, and the move isn't
# attempting to capture one of the moving player's own pieces, then
# a move instance is generated.  The additional parameter
# "requireCapture" will, if set, force the generated move to
# be a capture.  That latter functionality is only used
# by pawns that can only move  forward and sideways when
# capturing.
function move_from_jump(board::ChessBoard, start::Coord, jump::Coord, requireCapture::Bool = false)
    destination = start + jump

    if (!isValidCoord(destination))
        return nothing
    end

    destinationPiece = get_piece_at(board, destination)
    startPiece = get_piece_at(board, start)

    isLegalMove = destinationPiece.color != startPiece.color
    isCapture = isLegalMove && (destinationPiece.color != transparent)

    if (!isLegalMove || (requireCapture && !isCapture))
       return nothing
    else
       return Move(start, destination, isCapture, startPiece, destinationPiece)
    end
end



# Rooks, kings, bishops are all made up by
# rays and filtering.  A "ray" is a sequence of move-candidates generated by
# a starting position, and then stepping in some direction using the direction.
# The generation stops if the destination has travelled off the
# board, or a capture candidate has been generated.

function get_moves_from_ray(
	 direction::Coord,
	 color::Color,
	 board::ChessBoard,
	 start::Coord,
	 oneStepOnly::Bool)

    destination = start + direction
    result = []
    capture=false
    startPiece = get_piece_at(board, start)

    while (isValidCoord(destination) && !capture)
        destinationPiece = get_piece_at(board, destination)

        # Is the piece at the destination the same as the
        # piece being move, if so break off. No more moves
        # to generate.
	if destinationPiece.color == startPiece.color
          break
        end

        # Otherwise, if we're not looking at a blank space
        # as the target, we're capturing something
	capture = (bs != destinationPiece)

        # Generate the move and add it to the result
        move = Move(start, destination, capture, startPiece, destinationPiece)
        push!(result, move)

        # If we were only supposed to go one step (as for pawns)
        # then break now, otherwise continue.
	if (oneStepOnly)
           break
        else
	   destination +=  direction            
        end
    end
    return result
end


# Test movement of a single pawn
@test Move(a2, a3, false, wp, bs) == move_from_jump(startingBoard, a2, Coord(0,1))


moves_from_jumps(board::ChessBoard, start::Coord, jumps, requireCaptures::Bool) =
       [ move_from_jump(board, start, j, requireCaptures) for j in jumps ] |> valid_moves


@test [ Move(a2, a3, false, wp, bs)]   == moves_from_jumps(startingBoard, a2,[Coord(0,1)], false)



flatten_moves(x) = x |> Iterators.flatten |> collect

get_moves_from_rays(directions::Array{Coord, 1}, color::Color, board::ChessBoard, coord::Coord, oneStepOnly::Bool = false) = 
    [ get_moves_from_ray(gen, color, board, coord, oneStepOnly) for gen in directions] |> flatten_moves


##
##  Generating moves for specific pieces
##

knight_jumps = [Coord(-2, 1), Coord(2, 1),   Coord(1, 2),    Coord(-1, 2),
 	        Coord(2, -1), Coord(-2, -1), Coord(-1, -2),  Coord(1, -2)]
diagonal_rays                = [Coord(1,1), Coord(-1,-1), Coord(-1, 1), Coord(1, -1)]
vertical_and_horizontal_rays = [Coord(0,1), Coord(0,-1), Coord(1, 0), Coord(-1, 0)]
royal_rays                   = vcat(diagonal_rays, vertical_and_horizontal_rays)


get_moves_for_piece(piece::Knight, color::Color, board::ChessBoard, coord::Coord,  drop_king_moves::Bool) =
    moves_from_jumps(board, coord, knight_jumps, false)

get_moves_for_piece(piece::Bishop, color::Color,  board::ChessBoard, coord::Coord,  drop_king_moves::Bool) =
   get_moves_from_rays(diagonal_rays, color, board, coord)

get_moves_for_piece(piece::Rook, color::Color,  board::ChessBoard, coord::Coord,  drop_king_moves::Bool) = 
   get_moves_from_rays(vertical_and_horizontal_rays, color, board, coord)

get_royal_moves(color::Color, board::ChessBoard, coord::Coord, oneStepOnly::Bool = false,  drop_king_moves::Bool=false) = 
   get_moves_from_rays(royal_rays, color, board, coord, oneStepOnly)

# This move is only legal if
#  a) The king isn't getting close to another king
#  b) It's not putting itself in a position where it can be captured
#     immediately by the opponent (self-chec).

find_coords_of_piece(board, piece) = filter(c -> (get_piece_at(board, c) == piece), coords)

function is_legal_king_move(move::Move, board::ChessBoard)
    println("is_legal_king_move")
    opponents_color = other_color(move.startPiece.color)
    other_king = king_of_color(opponents_color)
    okc = find_coords_of_piece(board, other_king)[1]
    kc  = move.destination
    too_close = abs(kc.x-okc.x) == 1 || abs(kc.y-okc.y) == 1

    if too_close
        return false
    end

    board_with_move_applied = apply_move!(move, board)
    opponents_next_moves = get_moves(opponents_color, board_with_move_applied, drop_king_moves=true)
    opponent_can_win = isempty(filter(captures_king, opponents_next_moves))
    return !opponent_can_win
end    

get_moves_for_piece(piece::Queen, color::Color,  board::ChessBoard, coord::Coord,  drop_king_moves::Bool) =
    get_royal_moves(color, board, coord, false, drop_king_moves)

get_moves_for_piece(piece::King, color::Color,  board::ChessBoard, coord::Coord,  drop_king_moves::Bool) =
    drop_king_moves ?  filter(m->is_legal_king_move(m, board), get_royal_moves(color, board, coord, true, false)) : []


function get_moves_for_piece(piece::Pawn, color::Color,  board::ChessBoard, coord::Coord, drop_king_moves::Bool)

  pawn_start_line(color::Color) =  (color == black) ? 7 : 2
    
  # First we establish a jump direction that is color dependent
  # (for pawns only)
  speed = (color == white) ? 1 : -1
    
  # Then we establish a single non-capturing movement ray
  if  (coord.y == pawn_start_line(color))
     ncray = [Coord(0, speed), 2 * Coord(0, speed)]
  else
     ncray = [Coord(0, speed)]
  end

  # And a set of possibly capturing jumps
  captureJumps = [Coord(1,speed), Coord(-1, speed)]


  # This is  such a kludge!
  moves = [moves_from_jumps(board, coord, ncray, false),
    	   moves_from_jumps(board, coord, captureJumps, true)] |> flatten_moves |> valid_moves
  return moves
end


# A few simple smoketests to see if the basic mechanics works for pawns and knights.
@test [ Move(b1, c3, false, wk, bs), Move(b1, a3, false, wk, bs)] == get_moves_for_piece(wk.piecetype, white,  startingBoard, b1, false)
@test 2 == length(get_moves_for_piece(pawn,   white, startingBoard, a2, false))
@test 2 == length(get_moves_for_piece(knight, white, startingBoard, b1, false))


# From a chessboard, extract all the possible moves for all
# the pieces for a particular color on the board.
# Return an array (a set) of Move instances
get_moves(color::Color, board::ChessBoard, drop_king_moves::Bool  = false) =
    filter(m -> m isa Move, flatten_moves([get_moves_for_piece(get_piece_at(board, c).piecetype, color,  board, c, drop_king_moves)
                               for c in get_coords_for_pieces(color, board)]))

# All the opening moves for pawns and horses
@test 20 == length(get_moves(white, startingBoard))
@test 20 == length(get_moves(black, startingBoard))

