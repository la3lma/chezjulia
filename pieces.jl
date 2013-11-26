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
bk  = ChessPiece(black, knight,"T")
bb  = ChessPiece(black, bishop,"B");
bq  = ChessPiece(black, queen, "Q");
bki = ChessPiece(black, king,  "K");

wp  = ChessPiece(white, pawn,  "p");
wr  = ChessPiece(white, rook,  "r");
wk  = ChessPiece(white, knight,"t")
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
  wr wk wb wq wk wb wk wr;
  wp wp wp wp wp wp wp wp;
  bs bs bs bs bs bs bs bs;
  bs bs bs bs bs bs bs bs;
  bs bs bs bs bs bs bs bs;
  bs bs bs bs bs bs bs bs;
  bp bp bp bp bp bp bp bp;
  br bk bb bq bk bb bk br;
];

startingBoard = ChessBoard(startingBoardArray)

type Coord
    x:: Int64 # Should be Uint8!
    y:: Int64
end


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
@test getPieceAt(startingBoard, Coord(5,1)) == wk
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
    piece:: ChessPiece
end

function ==(m1::Move, m2::Move)
     return (m1.start == m2.start) &&
            (m1.destination == m2.destination) &&
	    (m1.capture == m2.capture) &&
	    (m1.piece == m2.piece)
end 

function getMovesForPiece(piece::Blank, board::ChessBoard, coord::Coord)
  # To be improved on
  []
end

function validMoves(moves)
     filter(m -> isValidCoord(m.destination), moves)
end
rookJumps = [Coord(2, 1),Coord(2, -1), Coord(-2, 1), Coord(-2, -1)]
function getMovesForPiece(piece::Rook, board::ChessBoard, coord::Coord)
     validMoves(board,movesFromJumps(coord, rookJumps, true))
end

# Towers, kings, bishops are all made up by
# raysand filtering.

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

function moveFromJump(board, start, jump, requireCaptures)
     destination = start + jump
 

     println("start = ")
     println(start)
     println("destination = ")
     println(destination)

    if (!isValidCoord(destination))
        return null
     end


     destinationPiece = getPieceAt(board, destination)
     startPiece = getPieceAt(board, start)

     println("destinationPiece = ")
     println(destinationPiece)

     println("startPiece = ")
     println(startPiece)

     println("startPiece.color = ")
     println(startPiece.color)

     println("destinationPiece.color = ")
     println(destinationPiece.color)


     isLegalMove = destinationPiece.color != startPiece.color
     isCapture = isLegalMove && (destinationPiece.color != transparent)


     println("isCapture = ")
     println(isCapture)

     println("isLegalMove = ")
     println(isLegalMove)


     if (!isLegalMove) 
        return null
     elseif (requireCaptures)
          if (isCapture)
	    return Move(start, destination, isCapture, destinationPiece)
	  else
	    return null
          end
     else
          return Move(start, destination, isCapture, destinationPiece)
     end
end

# Test movement of a single pawn
@test Move(Coord(1,2), Coord(1,3), false, getPieceAt(startingBoard, Coord(1,3))) == moveFromJump(startingBoard, Coord(1,2), Coord(0,1), false)


# Add a couple of unit tests here.
function movesFromJumps(board, start, jumps, requireCaptures)
    map(j -> moveFromJump(board, start, j, requireCaptures), jumps)
end

@test [ Move(Coord(1,2), Coord(1,3), false, getPieceAt(startingBoard, Coord(1,3)))] == movesFromJumps(startingBoard, Coord(1,2),[Coord(0,1)], false)

function movesFromRay(board, coord, ray, requireCaptures)
    return []
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
  moves = validMoves(
  	    union([movesFromJumps(board, coord, ncray, false),
    		   movesFromJumps(board, coord, captureJumps, true)]))
  
  # Finally we do the pawn-specific tranformation
  # if we find ourself ending up on the finishing line
  for move in moves
      if (move.destination.y == finishLine(color))
	 move.piece = queenOfColor(color)
      end
  end
  return moves
end

@test 16 == length(getMovesForPiece(pawn, white, startingBoard, Coord(1,2)))





# From a chessboard, extract all the possible moves for all
# the pieces for a particular color on the board.
# Return an array (a set) of Move instances
function getMoves(color::Color, board::ChessBoard)
	     union({ getMovesForPiece(getPieceAt(startingBoard, c).piecetype, color, startingBoard, c) 
            for c=getCoordsForPieces(black,startingBoard)
         })
end


# All the opening moves for pawns
@test 16 == length(getMoves(white, startingBoard))
@test 16 == length(getMoves(black, startingBoard))

