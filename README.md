# Sudoku
Data entry and solver for sudoku puzzles. A MacOS app.

Still in early development.

## Currently Implemented
1. Can open a .txt file if in the correct format and display the contents.
1. Can create and display a new empty puzzle in 2 sizes.
1. Can select a cell with the mouse.
1. Can move the selection with the arrow keys.
1. Allow editing of the puzzle cells.
1. Save an edited file to disk.
1. The document is marked edited when changes are made.
1. Undo/redo is working properly.
1. Speech verification of puzzles, including abort and restart.

## TODO List
For now, in no particular order, this is a list of things needed.

1. When an edited document is closed it is saved, but without a confirmation dialog.
1. I would like Cell and Drawer to know what SudokuPuzzle they belong to without sacrificing immutability.
1. Allow graphics files as input, converting them to puzzles.
1. A "show the solution" option.
1. An interactive "solve the puzzle" mode.
1. Find what caused the weird blue square on a new 9x9 puzzle.
