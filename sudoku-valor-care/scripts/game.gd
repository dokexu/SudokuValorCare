extends Node2D

@onready var grid:GridContainer = $GridContainer
# Called when the node enters the scene tree for the first time.

const GRIDSIZE = 9

# Grid of the Game
var gameGrid = [] # holds the buttons present in the game scene
var puzzle = [] # holds puzzle
var solutionGrid = [] # holds the answer
var solutionCount = 0 # number of valid solution, used for creating valid grid
var playerGrid = []

var selectedButton: Vector2i = Vector2(-1, -1)
var selectButtonAnswer = 0

# called when the node enters the scene tree for the first time
func _ready():
	bindSelectGridButtonActions()
	initGame()

# Called every frame. 'delta' is the elapsed time since the previous frame.
@warning_ignore("unused_parameter")
func _process(delta):
	pass

func initGame():
	createEmptyGrid()
	fillGrid(solutionGrid)
	createPuzzle(Settings.DIFFICULTY)
	
	populateGrid()
	drawSubgridLines()

func populateGrid():
	gameGrid = []
	playerGrid = []
	
	for i in range(GRIDSIZE):
		var row = []
		var playerRow = []
		for j in range(GRIDSIZE):
			row.append(createButton(Vector2(i, j)))
			playerRow.append(false)
		gameGrid.append(row)
		playerGrid.append(playerRow)

func createButton(pos: Vector2i):
	var row = pos[0]
	var col = pos[1]
	var ans = solutionGrid[row][col]
	
	var button = Button.new()
	if puzzle[row][col] != 0:
		button.text = str(puzzle[row][col]) 
	button.set("theme_override_font_sizes/font_size", 32)
	button.custom_minimum_size = Vector2(52,52)
	
	button.pressed.connect(onGridButtonPressed.bind(pos, ans))
	
	grid.add_child(button)
	return button

func onGridButtonPressed(pos: Vector2i, ans):
	selectedButton = pos
	selectButtonAnswer = ans # tracks the answer of the selected button

func bindSelectGridButtonActions():
	for button in $SelectGrid.get_children():
		var b = button as Button
		b.pressed.connect(onSelectGridButtonPressed.bind(b.text))

func onSelectGridButtonPressed(numberPressed):
	if selectedButton != Vector2i(-1, -1):
		var row = selectedButton[0]
		var col = selectedButton[1]
		var btn = gameGrid[row][col] as Button
		
		# only allow editing player-placed numbers
		if puzzle[row][col] != 0:
			return
		
		# if same number is already there delete it
		if btn.text == str(numberPressed) and playerGrid[row][col]:
			btn.text = ""
			playerGrid[row][col] = false
			# Reset stylebox
			btn.remove_theme_stylebox_override("normal")
			return
		
		btn.text = str(numberPressed)
		playerGrid[row][col] = true
		
		if Settings.SHOW_HINTS:
			var resultMatch = (numberPressed == str(selectButtonAnswer))
			var stylebox: StyleBoxFlat = btn.get_theme_stylebox("normal").duplicate(true)
			stylebox.bg_color = Color.SEA_GREEN if resultMatch else Color.DARK_RED
			btn.add_theme_stylebox_override("normal", stylebox)

func drawSubgridLines():
	await get_tree().process_frame
	
	var gridPos = grid.global_position - global_position
	var gridWidth = grid.size.x
	var gridHeight = grid.size.y
	var cellWidth = gridWidth / 9.0
	var cellHeight = gridHeight / 9.0
	
	for i in [0, 3, 6, 9]:
		var xOffset = i * cellWidth
		var yOffset = i * cellHeight
		
		# horizontal line
		var hLine = Line2D.new()
		hLine.width = 3.0
		hLine.default_color = Color.LIGHT_GRAY
		hLine.add_point(Vector2(gridPos.x, gridPos.y + yOffset))
		hLine.add_point(Vector2(gridPos.x + gridWidth, gridPos.y + yOffset))
		add_child(hLine)
		
		# vertical line
		var vLine = Line2D.new()
		vLine.width = 3.0
		vLine.default_color = Color.LIGHT_GRAY
		vLine.add_point(Vector2(gridPos.x + xOffset, gridPos.y))
		vLine.add_point(Vector2(gridPos.x + xOffset, gridPos.y + gridHeight))
		add_child(vLine)

# Generating sudoku grid
func generateSudokuSoln():
	# initialize solution array
	for i in range(GRIDSIZE):
		var row = []
		for j in range(GRIDSIZE):
			row.append(j + 1)
		randomize()
		row.shuffle()
		solutionGrid.append(row)
	
	print(solutionGrid)

func createEmptyGrid():
	# empty solution grid
	solutionGrid = []
	for i in range(GRIDSIZE):
		var row = []
		for j in range(GRIDSIZE):
			row.append(0)
		solutionGrid.append(row)

# generating valid sudoku grid
func fillGrid(gridObj):
	for i in range(GRIDSIZE):
		for j in range(GRIDSIZE):
			if gridObj[i][j] == 0:
				var numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
				numbers.shuffle()
				for num in numbers:
					if isValid(gridObj, i, j, num):
						gridObj[i][j] = num
						if fillGrid(gridObj):
							return true
						gridObj[i][j] = 0
				return false
	return true

func isValid(grd, row, col, num):
	return(
		# checks whether the number is a valid entry
		num not in grd[row] and 
		num not in getColumn(grd,col) and 
		num not in getSubgrid(grd, row, col)
	)

func getColumn(grd, col):
	var col_list = []
	for i in range(GRIDSIZE):
		col_list.append(grd[i][col])
	return col_list

func getSubgrid(grd, row, col):
	var subgrid = []
	var startRow = (row/3) * 3
	var startCol = (col/3) * 3
	for r in range(startRow, startRow + 3):
		for c in range (startCol, startCol + 3):
			subgrid.append(grd[r][c])
	return subgrid

# remove some values from the grid depending on the difficulty
func createPuzzle(difficulty):
	puzzle = solutionGrid.duplicate(true)
	var removals = difficulty * 10
	while removals > 0:
		var row = randi_range(0, 8)
		var col = randi_range(0, 8)
		if puzzle[row][col] != 0:
			var temp = puzzle[row][col]
			puzzle[row][col] = 0
			if not hasUniqueSolution(puzzle):
				puzzle[row][col] = temp
			else:
				removals -= 1

func hasUniqueSolution(puzzleGrid):
	# checks wheter the puzzle leads to one or more solution
	# ignore grids that has more than one solution
	solutionCount = 0
	tryToSolveGrid(puzzleGrid)
	return solutionCount == 1

func tryToSolveGrid(puzzleGrid):
	# takes the puzzle and tries to solve it
	for row in range(GRIDSIZE):
		for col in range(GRIDSIZE):
			if puzzleGrid[row][col] == 0:
				for num in range(1, 10):
					if isValid(puzzleGrid, row, col, num):
						puzzleGrid[row][col] = num
						tryToSolveGrid(puzzleGrid)
						puzzleGrid[row][col] = 0
				return
# keep track of the solution count
	solutionCount += 1
	if solutionCount > 1:
		return
