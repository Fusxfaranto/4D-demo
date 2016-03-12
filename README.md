# 4D-demo
This is a 4D cross-sectional renderer, with a 3rd person "character" (currently a box) that you can explore the little 4D world through.

## Building
### Linux/OS X/BSD/etc.
Should be pretty straightforward, you'll just have to set your D compiler in the makefile (currently the flags are all formatted for LDC), and then just `make` (and to run the program, `./main`).

### Windows
Still figuring this bit out!  I'll put instructions here once I do it, I swear.

## Controls
(Subject to change!)

Hold left shift to go faster or left control to go slower for any movement or rotation.

* W - forwards
* A - left
* S - backwards
* D - right
* Q - positive 4th direction
* E - negative 4th direction
* R - up
* F - down
* I - rotate up
* J - rotate left
* K - rotate down
* L - rotate right
* U - rotate "left" on the forwards-4th direction plane
* O - rotate "right" on the forwards-4th direction plane
* M - rotate "left" on the right-4th direction plane
* . - rotate "right" on the right-4th direction plane
* Z - zoom in
* X - zoom out
* 1 - return to original position/camera
* Space - print some debug information
