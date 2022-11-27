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
1. Can check a puzzle for conflicts and display them.
1. Can check if a puzzle has a solution without showing it.
1. Can show or hide the puzzle solution.
1. Allow import of graphics files, converting them to puzzles.

## TODO List
For now, in no particular order, this is a list of things needed.

1. When an edited document is closed it is saved, but without a confirmation dialog.
1. I would like Cell and Drawer to know what SudokuPuzzle they belong to without sacrificing immutability.
1. The puzzle solver can't handle all puzzles yet.
1. An interactive "solve the puzzle" mode.
1. The graphics file import has several problems:
    1. It is not very robust, many files crash it.
    1. There is no warning when an existing file will be overwritten.
    1. Files that have invalid text representations do not report the error.

