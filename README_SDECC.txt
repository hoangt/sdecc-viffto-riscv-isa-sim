README Addendum

Author: Mark Gottscho
Email: mgottscho@ucla.edu

Jan 25, 2017

To build custom memdatatrace/fault injection version of Spike for the Software-Defined ECC and ELC projects, the process is slightly different than outlined in README.md.

$ mkdir build
$ cd build
$ ../configure --prefix=$PWD --with-fesvr=$RISCV
$ make -j16 && make install

It's important to do the "make install". Even though the make process puts an executable in build/ , it will not resolve all the symbols in the shared libraries that are built until you make install to place libs in the right place.

It's also important you don't follow the README.md instructions of using --with-prefix=$RISCV, because then our custom Spike modifications in the header files won't be used.
