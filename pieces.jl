##
## The Chess kata in Julia
##
## The objective is to write a simple minimax/alpha-beta
## correctly playing chess game.  The purpose behind this
## objective is to do some nontrivial programming in Julia
## just to get a feel for it. Playing strength of the chess
## program is not something I'm very interested in :-)
##

import Base.show
using  Base.Test

type Color
   name:: String
   shortName:: String
end

function ==(c1::Color, c2::Color)
	c1.name == c2.name && c1.shortName == c2.shortName
end

@test Color("a","b") == Color("a", "b")
@test Color("a","b") != Color("b", "a")


black       = Color("Black", "b");
white       = Color("White", "w");
transparent = Color("Blank", " ");

@test white == white
@test white != black
@test white != transparent

@test black == black
@test black != white
@test black != transparent


abstract PieceType
type Pawn   <: PieceType end
type Rook   <: PieceType end
type Knight <: PieceType end
type Bishop <: PieceType end
type Queen  <: PieceType end
type King   <: PieceType end
type Blank  <: PieceType end

pawn   = Pawn();
rook   = Rook();
knight = Knight();
bishop = Bishop();
queen  = Queen();
king   = King();
blank  = Blank();

type ChessPiece
  color:: Color
  piecetype:: PieceType
  printrep:: String
end

function ==(cp1::ChessPiece, cp2::ChessPiece)
  return (cp1.color == cp2.color) &&
         (cp1.piecetype == cp2.piecetype) &&
	 (cp1.printrep == cp2.printrep)
end

bp  = ChessPiece(black, pawn,  "P");
br  = ChessPiece(black, rook,  "R");
bk  = ChessPiece(black, knight,"g")
bb  = ChessPiece(black, bishop,"B");
bq  = ChessPiece(black, queen, "Q");
bki = ChessPiece(black, king,  "K");

wp  = ChessPiece(white, pawn,  "p");
wr  = ChessPiece(white, rook,  "r");
wk  = ChessPiece(white, knight,"g")
wb  = ChessPiece(white, bishop,"b");
wq  = ChessPiece(white, queen, "q");
wki = ChessPiece(white, king,  "k");

bs = ChessPiece(transparent, blank,  " ");

type ChessBoard
   # This must be an 8x8 matrice. That fact shoul
   # be a constraint somewhere
   board::Array{ChessPiece}
end


startingBoardArray = [
  wr wk wb wq wki wb wk wr;
  wp wp wp wp wp  wp wp wp;
  bs bs bs bs bs  bs bs bs;
  bs bs bs bs bs  bs bs bs;
  bs bs bs bs bs  bs bs bs;
  bs bs bs bs bs  bs bs bs;
  bp bp bp bp bp  bp bp bp;
  br bk bb bq bki bb bk br;
];

startingBoard = ChessBoard(startingBoardArray)

type Coord
    x:: Int64 # Should be Uint8!
    y:: Int64
end


function intToChessLetter(i::Integer)
    # This cries out for using a table etc.
    if (i == 1)
        return "a"
    elseif (i == 2)
        return "b"
    elseif (i == 3)
        return "c"
    elseif (i == 4)
        return "d"
    elseif (i == 5)
        return "e"
    elseif (i == 6)
        return "f"
    elseif (i == 7)
        return "g"
    elseif (i == 8)
        return "h"
    else
        return "X"
    end
end

@test intToChessLetter(1) == "a"
@test intToChessLetter(8) == "h"
@test intToChessLetter(81) == "X"


# # Printing coordds
function show(io::IO, m::Coord)
   if (isValidCoord(m))
      @printf(io, "%s%d", intToChessLetter(m.x), m.y)
   else
      @printf(io, "Coord(%d, %d)", m.x, m.y)
   end
end


# Expand this to all coordinates for convenience
b1=Coord(2,1)
a2=Coord(1,2)
a3=Coord(1,3)
b2=Coord(2,1)
c3=Coord(3,3)
c2=Coord(3,2)


# Coordinates are linar, so we must define addition and multiplication
# with numbers

+(c1::Coord, c2::Coord) = Coord(c1.x + c2.x, c1.y + c2.y)
*(n::Number, c::Coord)  = Coord(n * c.x, n * c.y)
*(c::Coord,  n::Number) = n * c
==(c1::Coord, c2::Coord) = (c1.x == c2.x && c1.y == c2.y)

@test Coord(3,3) == Coord(1,1) + Coord(2,2)


isValidOrdinate(c::Int)  =  1 <= c && c <= 8

@test !isValidOrdinate(0)
@test  isValidOrdinate(1)
@test  isValidOrdinate(8)
@test !isValidOrdinate(9)

function isValidCoord(coord::Coord)
    return isValidOrdinate(coord.x) &&
           isValidOrdinate(coord.y)
end

@test isValidCoord(Coord(1,1))
@test isValidCoord(Coord(1,2))
@test isValidCoord(Coord(1,3))
@test !isValidCoord(Coord(0,2))
@test !isValidCoord(Coord(1,0))


function getPieceAt(board::ChessBoard, coord::Coord)
    return board.board[coord.y, coord.x]
end



# Check that the coordinates are not messed up
@test getPieceAt(startingBoard, Coord(1,1)) == wr
@test getPieceAt(startingBoard, Coord(2,1)) == wk
@test getPieceAt(startingBoard, Coord(5,1)) == wki
@test getPieceAt(startingBoard, Coord(4,1)) == wq
@test getPieceAt(startingBoard, Coord(4,2)) == wp


## XXX This is a very inefficient representation.  Can
 ##     we do better?

## Printing pieces
show(io::IO, cd::ChessPiece) = show(io, cd.printrep)

## Printing chessboards
function show(io::IO, cb::ChessBoard)
 for y1 = 1:8
  y = 9 - y1;
  print(io, y)
   for x = 1:8
       @printf(io, "%s",  cb.board[y, x].printrep)
   end
   println(io, y)
 end
end


##
##  Representing movement
##



function allCoords()
    result = Coord[]
     for y = 1:8, x = 1:8
        c = Coord(x, y)
        push!(result, c)
     end
     return result
end

coords = allCoords()

@test 64 == length(coords)




# Get coordinates for all the pieces of a particular
# color
function getCoordsForPieces(color::Color, board::ChessBoard)
   return filter(c -> (getPieceAt(board, c).color == color), coords)
end


type Move
    start:: Coord
    destination:: Coord
    capture:: Bool
    startPiece:: ChessPiece
    destinationPiece:: ChessPiece
end

# Take a look at http://en.wikipedia.org/wiki/Chess_notation, print moves
# in an orderly algebraic or long algebraic manner.


function ==(m1::Move, m2::Move)
     return (m1.start == m2.start) &&
            (m1.destination == m2.destination) &&
	    (m1.capture == m2.capture) &&
	    (m1.startPiece == m2.startPiece) &&
	    (m1.destinationPiece == m2.destinationPiece)
end


function getMovesForPiece(piece::Blank, board::ChessBoard, coord::Coord)
  # To be improved on
  []
end

function validMoves(moves::Array{Move, 1})
     filter(m -> isValidCoord(m.destination), moves)
end


function moveFromJump(board::ChessBoard, start::Coord, jump::Coord, requireCaptures::Bool)
    destination = start + jump

    if (!isValidCoord(destination))
        return null
     end


     destinationPiece = getPieceAt(board, destination)
     startPiece = getPieceAt(board, start)

     isLegalMove = destinationPiece.color != startPiece.color
     isCapture = isLegalMove && (destinationPiece.color != transparent)

     if (!isLegalMove)
        return null
     elseif (requireCaptures)
          if (isCapture)
	    return Move(start, destination, isCapture, startPiece, destinationPiece)
	  else
	    return null
          end
     else
          return Move(start, destination, isCapture, startPiece, destinationPiece)
     end
end

# Test movement of a single pawn
@test Move(a2, a3, false, wp, bs) == moveFromJump(startingBoard, a2, Coord(0,1), false)


function movesFromJumps(board::ChessBoard, start::Coord, jumps::Array{Coord,1}, requireCaptures::Bool)
#    map(j ->
#	  moveFromJump(board, start, j, requireCaptures),
#        jumps)
    #  XXX I don't understand why the code above fails and the code below works.
    result = []
    for j in jumps
       move = moveFromJump(board, start, j, requireCaptures)
       if (move != null)
           result = [result..., move]
       end
    end
    return result
end

@test [ Move(a2, a3, false, wp, bs)]   == movesFromJumps(startingBoard, a2,[Coord(0,1)], false)


knightJumps = [Coord(-2, 1), Coord(2, 1), Coord(1, 2),  Coord(-1, 2),
	     Coord(2, -1), Coord(-2, -1), Coord(-1, -2),  Coord(1, -2)]

function getMovesForPiece(piece::Knight, color::Color, board::ChessBoard, coord::Coord)
    movesFromJumps(board, coord, knightJumps, false)
end


# this test shouldn't depend on the order of items in the list, it should treat
# this as a test for collection equality
@test [ Move(b1, c3, false, wk, bs), Move(b1, a3, false, wk, bs)] == getMovesForPiece(wk.piecetype, white,  startingBoard, b1)

# Rooks, kings, bishops are all made up by
# rays and filtering.

function getMovesForPiece(piece::PieceType, color::Color,  board::ChessBoard, coord::Coord)
  []
end

function pawnStartLine(color::Color)
   if (color == black)
     return 7
   else
     return 2
   end
end

function finishLine(color::Color)
    if (color == black)
        return 1
    else
        return 8
    end
end


function getMovesForPiece(piece::Pawn, color::Color,  board::ChessBoard, coord::Coord)
  # First we establish a jump speed that is color dependent
  # (for pawns only)
  if (color == white)
     speed = 1
  else
     speed = -1
  end

  # Then we establish a single non-capturing movement ray
  if  (coord.y == pawnStartLine(color))
     ncray = [Coord(0,speed), 2 * Coord(0, speed)]
  else
     ncray = [Coord(0,speed)]
  end

  # And a set of possibly capturing jumps
  captureJumps = [Coord(1,speed), Coord(-1, speed)]

  # Then we have to process these alternatives
  # to check that they are inside the board etc.
  moves = union([movesFromJumps(board, coord, ncray, false),
    		 movesFromJumps(board, coord, captureJumps, true)])
  moves = filter(m -> m != null, moves) #Kludge

  # Finally we do the pawn-specific tranformation
  # if we find ourself ending up on the finishing line
  for move in moves
      if (move.destination.y == finishLine(color))
	 move.piece = queenOfColor(color)
      end
  end
  return moves
end

# XXX Parameters for getMovesForPiece are screwed up.
@test 2 == length(getMovesForPiece(pawn,   white, startingBoard, a2))
@test 2 == length(getMovesForPiece(knight, white, startingBoard, b1))

# From the intertubes
flatten{T}(a::Array{T,1}) = any(map(x->isa(x,Array),a))? flatten(vcat(map(flatten,a)...)): a
flatten{T}(a::Array{T}) = reshape(a,prod(size(a)))
flatten(a)=a

# From a chessboard, extract all the possible moves for all
# the pieces for a particular color on the board.
# Return an array (a set) of Move instances
function getMoves(color::Color, board::ChessBoard)
	    flatten( union({ getMovesForPiece(getPieceAt(startingBoard, c).piecetype, color, startingBoard, c)
                for c=getCoordsForPieces(color,startingBoard)
         }))
end

# All the opening moves for pawns
@test 20 == length(getMoves(white, startingBoard))
@test 20 == length(getMoves(black, startingBoard))

