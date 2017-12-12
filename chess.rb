require "yaml"
class GameBoard
  attr_reader :check, :state, :pieces, :turn, :kings

  def initialize
    @turn = 1
    @check = [[false,nil], [false,nil]]
    @pieces = Hash.new(nil)
    @kings = [King.new("black", [4,7]),King.new("white", [4,0])]

    colors = ["black", "white"]
    colors.each do |color|
      if color == "black"
        y = 7
        z = 6
      else
        y = 0
        z = 1
      end
      @pieces[[0,y]] = Rook.new(color, [0,y])
      @pieces[[1,y]] = Knight.new(color, [1,y])
      @pieces[[2,y]] = Bishop.new(color, [2,y])
      @pieces[[3,y]] = Queen.new(color, [3,y])
      @pieces[[4,y]] = color == "black" ? @kings[0] : @kings[1]
      @pieces[[5,y]] = Bishop.new(color, [5,y])
      @pieces[[6,y]] = Knight.new(color, [6,y])
      @pieces[[7,y]] = Rook.new(color, [7,y])
      (0..7).each {|x| @pieces[[x,z]] = Pawn.new(color,[x,z])}
    end
    @pieces.each_pair {|key, value| value.list_moves}
  end

  def prompt
    begin
      puts "#{@turn == 0 ? "Black" : "White"} Player, make your move."
      playerMove = gets.chomp
      if playerMove.downcase == "save"
        self.save
      else
        playerMove = playerMove.split(" ")
        playerMove[0] = [translate(playerMove[0][0]),playerMove[0][1].to_i-1]
        playerMove[2] = [translate(playerMove[2][0]),playerMove[2][1].to_i-1]
        @pieces[playerMove[0]].color
        playerMove
      end
    rescue
      print "\nOutside of range. Use a-h and 1-8 (ex. 'h2 to h3')\n\n"
      retry
    end
  end

  def translate(letter)
    case letter.downcase
    when "a" then 0
    when "b" then 1
    when "c" then 2
    when "d" then 3
    when "e" then 4
    when "f" then 5
    when "g" then 6
    when "h" then 7
    end
  end

  def move(player_move)
    start_pos = player_move[0]
    end_pos = player_move[2]
    @turn == 0 ? color = "black" : color = "white"
    if @pieces[start_pos].color == color
      if @check[@turn][0]
        if @pieces[start_pos].char[1] == "K"
          if valid_moves(start_pos).include?(end_pos) && (@check[@turn][1] == end_pos || !valid_moves(@check[@turn][1]).include?(end_pos))
            @pieces[end_pos] = @pieces[start_pos]
            @pieces[start_pos] = nil
            @pieces[end_pos].position = end_pos
            @turn = (@turn + 1) % 2
          else
            print "\nMove not valid while checked.\n"
          end
        elsif valid_moves(start_pos).include?(end_pos) && valid_check_moves(@check[@turn][1]).include?(end_pos)
          @pieces[end_pos] = @pieces[start_pos]
          @pieces[start_pos] = nil
          @pieces[end_pos].position = end_pos
          @turn = (@turn + 1) % 2
        else
          print "\nMove not valid while checked.\n"
        end
      elsif valid_moves(start_pos).include?(end_pos)
        @pieces[end_pos] = @pieces[start_pos]
        @pieces[start_pos] = nil
        @pieces[end_pos].position = end_pos
        @turn = (@turn + 1) % 2
      else
        print "\nInvalid move.\n"
      end
    else
      print "\nThat's not your piece!\n"
    end

    pawn_transform(end_pos)

    check_status
    if @check[(@turn+1)%2][0]
      puts "That move would put your king in check!"
      undo(end_pos, start_pos)
    end
  end

  def valid_check_moves(check_pos)
    validCheckMoves = [check_pos]
    unless @pieces[check_pos].char[1] == "N" || @pieces[check_pos].char[1] == "P"
      end_pos = check_pos
      start_pos = @kings[@turn].position
      xdiff = check_pos[0] - @kings[@turn].position[0]
      ydiff = check_pos[1] - @kings[@turn].position[1]
      if xdiff < 0 && ydiff < 0
        (1..(xdiff.abs-1)).each {|x| validCheckMoves << [end_pos[0]+x, end_pos[1]+x]}
      elsif xdiff < -1 && ydiff > 1
        (1..(xdiff.abs-1)).each {|x| validCheckMoves << [end_pos[0]+x, end_pos[1]-x]}
      elsif xdiff > 1 && ydiff > 1
        (1..(xdiff.abs-1)).each {|x| validCheckMoves << [start_pos[0]+x, start_pos[1]+x]}
      elsif xdiff > 1 && ydiff < -1
        (1..(xdiff.abs-1)).each {|x| validCheckMoves << [start_pos[0]+x, start_pos[1]-x]}
      elsif xdiff == 0 && ydiff < -1
        (1..(ydiff.abs-1)).each {|y| validCheckMoves << [end_pos[0], end_pos[1]+y]}
      elsif xdiff == 0 && ydiff > 1
        (1..(ydiff.abs-1)).each {|y| validCheckMoves << [end_pos[0], start_pos[1]+y]}
      elsif xdiff < -1 && ydiff == 0
        (1..(xdiff.abs-1)).each {|x| validCheckMoves << [end_pos[0]+x, end_pos[0]]}
      elsif xdiff > 1 && ydiff == 0
        (1..(xdiff.abs-1)).each {|x| validCheckMoves << [start_pos[0]+x, start_pos[0]]}
      end
    end
    validCheckMoves
  end

  def valid_moves(start_pos)
    piece = @pieces[start_pos]
    piece.list_moves
    validMoves = []
    piece.moves.each do |x|
      if path_clear?(start_pos,x)
        if @pieces[x] == nil
          validMoves << x unless piece.char[1] == "P" && x[0] != start_pos[0]
        elsif @pieces[x].color != piece.color
          validMoves << x unless piece.char[1] == "P" && x[0] == start_pos[0]
        end
      end
    end
    validMoves
  end

  def path_clear?(start_pos, end_pos)
    if @pieces[start_pos].char[1]=="N"
      true
    else
      xdiff = end_pos[0] - start_pos[0]
      ydiff = end_pos[1] - start_pos[1]
      clear = true
      if xdiff < -1 && ydiff < -1
        (1..(xdiff.abs-1)).each {|x| clear = false unless @pieces[[end_pos[0]+x, end_pos[1]+x]] == nil}
      elsif xdiff < -1 && ydiff > 1
        (1..(xdiff.abs-1)).each {|x| clear = false unless @pieces[[end_pos[0]+x, end_pos[1]-x]] == nil}
      elsif xdiff > 1 && ydiff > 1
        (1..(xdiff.abs-1)).each {|x| clear = false unless @pieces[[start_pos[0]+x, start_pos[1]+x]] == nil}
      elsif xdiff > 1 && ydiff < -1
        (1..(xdiff.abs-1)).each {|x| clear = false unless @pieces[[start_pos[0]+x, start_pos[1]-x]] == nil}
      elsif xdiff == 0 && ydiff < -1
        (1..(ydiff.abs-1)).each {|y| clear = false unless @pieces[[end_pos[0], end_pos[1]+y]] == nil}
      elsif xdiff == 0 && ydiff > 1
        (1..(ydiff.abs-1)).each {|y| clear = false unless @pieces[[end_pos[0], start_pos[1]+y]] == nil}
      elsif xdiff < -1 && ydiff == 0
        (1..(xdiff.abs-1)).each {|x| clear = false unless @pieces[[end_pos[0]+x, end_pos[1]]] == nil}
      elsif xdiff > 1 && ydiff == 0
        (1..(xdiff.abs-1)).each {|x| clear = false unless @pieces[[start_pos[0]+x, start_pos[1]]] == nil}
      end
      clear
    end
  end

  def pawn_transform(position)
    if @pieces[position].char[1] == "P" && (position[1] == 0 || position[1] == 7)
      puts "Would you like a queen or a knight?"
      answer = gets.chomp[0].downcase
      if answer == "q"
        @pieces[position] = Queen.new(@pieces[position].color, position)
      else
        @pieces[position] = Knight.new(@pieces[position].color, position)
      end
      puts "The #{@pieces[position].color} pawn is now a #{answer == "q" ? "queen" : "knight"}!"
    end
  end

  def display
    print "   __ __ __ __ __ __ __ __\n8 |"
    (0..7).reverse_each do |y|
      (0..7).each do |x|
        if @pieces[[x,y]] == nil
          print "__|"
        else
          print "#{@pieces[[x,y]].char}|"
        end
        if x == 7
          print "\n"
          print "#{y} |" unless y == 0
        end
      end
    end
    print "   a  b  c  d  e  f  g  h \n\n"
  end

  def end_of_turn
    @check.each_with_index {|x,i| puts "Check on #{i==0 ? "black" : "white"}." if x[0]}
  end

  def checkmate
    mate = false
    if @check[@turn][0]
      mate = true
      @pieces.each_pair do |key, value|
        next if value == nil || value.char[1] == "K" || value.color == @pieces[@check[@turn][1]].color
        valid_check_moves(@check[@turn][1]).each {|move| mate = false if valid_moves(key).include?(move) }
      end
      mate = false if valid_moves(@pieces.key(@kings[@turn])).include?(@check[@turn][1])
      valid_moves(@pieces.key(@kings[@turn])).each do |move|
        included = false
        @pieces.each_pair do |key, value|
          next if value == nil || value.color == @kings[@turn].color
          included = true if valid_moves(key).include?(move)
        end
        mate = false unless included
      end
    end
    mate
  end

  def check_status
    @check = [[false,nil], [false,nil]]
    @pieces.each_pair do |key, value|
      next if value == nil
      @check[value.color == "black" ? 1 : 0] = [true, key] if valid_moves(key).include?(opp_king_position(value.color[0].downcase))
    end
  end

  def opp_king_position(color)
    color[0].downcase == "b" ? @pieces.key(@kings[1]) : @pieces.key(@kings[0])
  end

  def undo(end_pos, start_pos)
    @pieces[start_pos] = @pieces[end_pos]
    @pieces[end_pos] = nil
    @pieces[start_pos].position = start_pos
    @turn = (@turn + 1) % 2
    check_status
    move(prompt)
  end

  def win
    print "Checkmate.\nCongratulations, #{@turn==1 ? "Black" : "White"} Player. You win!\n"
    play_again?
  end

  def play_again?
    puts "Would you like to play again?"
    answer = gets.chomp[0].downcase
    $quit = true if answer == "n"
  end

  def save
    File.open('savegame', 'w') {|f| f.write(YAML.dump(self)) }
    puts "Game saved."
    prompt
  end

end

class GamePiece
  attr_accessor :color, :position, :moves, :char#, :symbol
  def initialize(color, position)
    @color = color
    @position = position
    @moves = []
  end
  def list_moves
    @moves = [[position[0],position[1]+1]]
  end
  def char
    @char
  end
end

class King < GamePiece
  def initialize(color, position)
    super
    @char = color[0].downcase + "K"
    #@color[0] == "b" ? @symbol = "\u265a" : @symbol = "\u2654"
  end
  def list_moves
    @moves = []
    x_start = @position[0]
    y_start = @position[1]
    (-1..1).each do |x|
      if x_start + x < 8 && x_start + x >= 0
        (-1..1).each do |y|
          if y_start + y < 8 && y_start + y >= 0
            @moves << [x_start+x, y_start+y]
          end
        end
      end
    end
    @moves = @moves - [[x_start, y_start]]
  end
end

class Queen < GamePiece
  def initialize(color, position)
    super
    @char = color[0].downcase + "Q"
  end
  def list_moves
    @moves = []
    x_start = @position[0]
    y_start = @position[1]
    (-7..7).each do |x|
      if x_start + x < 8 && x_start + x >= 0
        @moves << [x_start+x, y_start]
        if y_start + x >= 0 && y_start + x < 8
          @moves << [x_start+x, y_start+x]
          @moves << [x_start, y_start+x]
        end
        @moves << [x_start+x, y_start-x] if y_start - x >= 0 && y_start - x < 8
      elsif y_start + x < 8 && y_start + x >= 0
        @moves << [x_start, y_start +x]
      end
    end
    @moves = @moves - [[x_start, y_start]]
    @moves.uniq!
  end
end

class Bishop < GamePiece
  def initialize(color, position)
    super
    @char = color[0].downcase + "B"
  end
  def list_moves
    @moves = []
    x_start = @position[0]
    y_start = @position[1]
    (-7..7).each do |x|
      if x_start + x < 8 && x_start + x >= 0
        @moves << [x_start+x, y_start+x] if y_start + x >= 0 && y_start + x < 8
        @moves << [x_start+x, y_start-x] if y_start - x >= 0 && y_start - x < 8
      end
    end
    @moves = @moves - [[x_start, y_start]]
  end
end

class Rook < GamePiece
  def initialize(color, position)
    super
    @char = color[0].downcase + "R"
  end
  def list_moves
    @moves = []
    x_start = @position[0]
    y_start = @position[1]
    (-7..7).each do |x|
      @moves << [x_start+x, y_start] if x_start + x < 8 && x_start + x >= 0
      @moves << [x_start, y_start+x] if y_start + x < 8 && y_start + x >= 0
    end
    @moves = @moves - [[x_start, y_start]]
  end
end

class Knight < GamePiece
  def initialize(color, position)
    super
    @char = color[0].downcase + "N"
  end
  def list_moves
    @moves = []
    x=@position[0]
    y=@position[1]
    unless x < 2
      xcopy = x - 2
      ycopy = y - 1
      @moves << [xcopy,ycopy] unless ycopy < 0
      ycopy += 2
      @moves << [xcopy,ycopy] unless ycopy > 7
    end
    unless x < 1
      xcopy = x - 1
      ycopy = y - 2
      @moves << [xcopy,ycopy] unless ycopy < 0
      ycopy += 4
      @moves << [xcopy,ycopy] unless ycopy > 7
    end
    unless x > 6
      xcopy = x + 1
      ycopy = y - 2
      @moves << [xcopy,ycopy] unless ycopy < 0
      ycopy += 4
      @moves << [xcopy,ycopy] unless ycopy > 7
    end
    unless x > 5
      xcopy = x + 2
      ycopy = y - 1
      @moves << [xcopy,ycopy] unless ycopy < 0
      ycopy += 2
      @moves << [xcopy,ycopy] unless ycopy > 7
    end
  end
end

class Pawn < GamePiece
  def initialize(color, position)
    super
    @char = color[0].downcase + "P"
  end
  def list_moves
    @moves = []
    x_start = @position[0]
    y_start = @position[1]
    if @color[0].downcase == "b"
      if y_start > 0
        @moves << [x_start, y_start-1]
        @moves << [x_start-1, y_start-1]
        @moves << [x_start+1, y_start-1]
        @moves << [x_start, y_start-2] if y_start == 6
      end
    else
      if y_start < 7
        @moves << [x_start, y_start+1]
        @moves << [x_start-1, y_start+1]
        @moves << [x_start+1, y_start+1]
        @moves << [x_start, y_start+2] if y_start == 1
      end
    end
  end
end

def new_or_load?
  puts "Start a (N)ew game, or (L)oad an existing game?"
  answer = gets.chomp[0].downcase
  if answer == "l"
    if File.exists? 'savegame'
      YAML.load(File.read('savegame'))
    else
      puts "No saved data found. Starting a new game."
      GameBoard.new
    end
  else
    GameBoard.new
  end
end

until $quit
  current_game = new_or_load?
  puts "\nLet's play a game of chess! Type 'save' at any time to save the game."
  current_game.display
  until current_game.checkmate
    current_game.move(current_game.prompt)
    current_game.display
    current_game.end_of_turn
  end
  current_game.win
end
