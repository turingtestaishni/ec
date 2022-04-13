# Reimplementation Notes

## Installation

1. Forked the original repo and ran 
      `git clone`
      `git submodule update --recursive --init`

2. Created and activated a virtual environment to install dependencies
     `python3 -m venv env-dreamcoder`
     `source env-dreamcoder/bin/activate`

3. Install dependencies from `requirements.txt` file
     `python3 -m pip install -r requirements.txt`
  
      Installation was stuck upon trying twice on `multiprocess==0.70.7` so I removed it from the file. 

4. It seems that installed libraries from step 3 did not show up in pip list. So I manually installed all packages from requriements.txt

      For `Box2D-kengz==2.3.3`, I had to install `brew install swig`. 

      The following libraries did not have a version match so I installed the latest version: `numpy==1.22.3`, `pillow==9.1.0`, `pygame==2.1.2`, `pyzmq==22.3.0`, `scikit-learn==1.0.2`, `multiprocess==0.70.12.2` are latest versions.

## Inspecting files
Understanding the main structure of the code using [Software Architecture doc](https://github.com/turingtestaishni/ec/blob/master/docs/software-architecture.md)
1. Representation
      Programs are lambda-calculus expressions. These are represented using the de Bruijn notation which avoids complications caused by variable names. [This handout](https://www.cs.cornell.edu/courses/cs4110/2018fa/lectures/lecture15.pdf) from Cornell provides a good guide for working with this representation.

      A bound variable can be viewed as a pointer to the lambda that binds it. Example, the y in λx.λy.y x points to the first λ and the x points to the second λ when read from rightmost lambda (index 0) to left (index increments by 1).  

      de Bruijn notation has the following grammar for lambda expressions: 
          e ::= n | λ.e | e e

      In this grammar, variables are represented by integers n that represent the index of their binder. 
      Standard -> de Bruijn
      λx.x -> λ.0
      λz.z -> λ.0
      λx.λy.x -> λ.λ.1
      λx.λy.λs.λz.x s (y s z) -> λ.λ.λ.λ.3 1 (2 1 0)
      (λx.x x)(λ.x.x x) -> (λ.0 0)(λ.0 0)
      (λx.λx.x)(λy.y) -> (λ.λ.0)(λ.0)

      If there is a type environment that maps variables x, y to some integer, then that mapping is also used in the de Bruijn notation. 

      Index shifting can happen.

2. Structure of different program types
      `Primitive` program type specifies programs that make up the initial library.

      `Application` and `Abstraction` program types allow nesting of programs within programs during enumeration. 

3. Every program object specifies a type attribute. There are various types:
            1. Ground types such as `int`, `bool`.
            2. Type variables such as `alpha`, `gamma`, `beta`.
            3. Types built from type constructors such as `list[int]`, `char->bool`, `alpha->list[alpha]`
      The type objects are used to describe expected input and output type of program, and to check that generated program is well-typed during enumeration. 

      There are two files that deal with types, one is `dreamcoder/type.py` and the other is `type.ml`.
      
      `type.ml` has code to create and transform types (instantiate, unify, apply). Enumeration module uses it to check if generated program is well-typed. The Task data with input-output examples also reference Type class to match tasks with suitable programs during enumeration. 
      
      It seems `type.py` is not called anywhere so far, but has code to interact with json files and defines all the ground types and list types.

4. `Grammar` has the initial library of code, and also includes the learned library of code. A `Grammar` object is made up of `Program` objects (`Primitive` and `Invented` programs) and a numerical weight that is used to calculate the probability of a given program being used when creating new programs. 
       `Grammar` data is input to `Enumeration` module as it creates programs from the current library.
       It is also input to the `Dream` module `helmholtz.ml` which generates training data for `recognition.py`. `compression.ml` updates the library. 

## Dreamcoder's Workflow
(Conceptual)
1. There should be some initial library 
2. Dreaming and Program Enumeration occur parallelly using library in 1
3. Recognition model gets trained
4. Program Enumeration runs again using the recognition model
5. Abstraction/Compression adds refactored code to the library
6. Visualize library
7. Checkpoints are saved to binary files using `pickle` (these can be used to resume training from some state or visualize the system performance during training/testing using the script `bin/graphs.py`) 

(Programmatical Calls)
1. User runs `dreamcoder.py` using cmd-ling args or a checkpoint file to resume training from some saved state. 

This file has a class for ECResult which handles how the result is output to the user, and an ecIterator function which invokes all the  steps in one iteration of DreamCoder and yields the result. 
There are some other functions that handle the output formatting, logging, and cmd-line arguments parsing. 

The following steps get invoked
      1. calls `dreaming.py` by calling the `backgroundHelmholtzEnumeration` function which creates multiple background workers to run Ocaml processes in parallel
     `dreaming.py` has two functions, one called `helmholtzEnumeration` and the other `backgroundHelmholtzEnumeration` which makes calls to the former asynchronously. The workers output a JSON response which is loaded and read as frontiers that need to be searched in a `get()` function.
     There is a main function with simple grammar to test enumeration (I will try to run this code tonight).
     
      2.  in parallel, `enumeration.py` enumerates new programs from current library (isomorphic to generating dreams in step 1). It creates a new child process to run solver.ml which executes the enumeration. The user can use cmd-line-args to control how many CPUs this runs in parallel. 
      `solver.ml` "generates programs that successfully solve the input tasks are represented in a lambda calculus and returned in JSON format to the parent Python process."
      inspect solver.ml

      3. 


## Running scripts
1. Ran `python bin/logo.py --enumeration 1` but this returns `OSError: [Errno 8] Exec format error: './logoDrawString'` which occurs when the executable has been made for a different architecture. My machine is 64-bit. 

`Line 42` in `makeLogoTasks.py` invokes this binary file. The Makefile and bash script for logo are in `ec/data/geom`.  Could I make this executable on this machine? 

In the `Create New Domains` doc there is a section that says we need to rebuild the ocaml binaries in root of the repo. I am going to try that. 

Ran `make clean`. I got this error `bin/sh: jbuilder: command not found make: *** [all] Error 127` possibly because I am not running within the singularity container, so I need to install the Ocaml libraries dependencies first. 

`opam update`
`opam switch 4.06.1+flambda` this didn't work because I have opam 4.11.1
``eval `opam config env`` 
`opam install ppx_jane core re2 yojson vg cairo2 camlimages menhir ocaml-protoc zmq`

`make` and `make clean` still didn't work, when I looked up the issue was that jbuilder has now been replaced with `dune` in `opam`. I just replaced all occurences of `jbuilder` in the `Makefile` in `root` with `dune`. `make clean` worked.

`make` did not work, it complained that `File "jbuild", line 1 characters 0-0: Error: jbuild files are no longer supported, please convert this file to a dune file instead. Note: You can use "dune upgrade" to convert your project to dune.` 
`eval $(opam config env)` no change
`dune upgrade`
`make clean` removed all files again
`make` complained `library re2 not found`
`opam switch default`
`opam install ppx_jane core re2 yojson vg cairo2 camlimages menhir ocaml-protoc zmq`
`make clean` worked
`make` worked but errors
`Error: dune__exe__Protonet-tester corresponds to an invalid module name -> required by _build/default/solvers/.solver.eobjs/dune__exe.ml-gen -> required by _build/default/solvers/.solver.eobjs/native/dune__exe.cmx -> required by _build/default/solvers/solver.exe`
The `dune__exe__` problem occurs because dune is building wrapped executables by default since version 2.0, I disabled this by adding `(wrapped_executables false)` in `dune-project` file. [Reference](https://github.com/ocaml/dune/issues/3518).
`make` ran with just warnings. 

`dune` treats warnings as errors so I followed the docs and created a file called `dune` in the root and made the warnings non-fatal. There still are some type errors utils.ml, parser.ml, CachingTable.ml, 

I am going to try to run the singularity container

-- looking at how judith fan implemented dreamcoder -- seems like they manually extracted the tower task into python files.






# Table of contents
1. [Overview](#overview)
2. [Getting Started](#getting-started)
    1. [Getting the code](#getting-the-code)
    2. [Running using singularity](#running-using-singularity)
    3. [Running tasks from the commandline](#running-tasks-from-the-commandline)
    4. [Understanding console output](#understanding-console-output)
    5. [Graphing the results](#graphing-the-results)
3. [Additional Information](#additional-information)
    1. [Creating new domains](#creating-new-domains)
    2. [Installing Python dependencies](#installing-python-dependencies)
    3. [Building the OCaml binaries](#building-the-ocaml-binaries)
    4. [Build rust compressor](#build-rust-compressor)
    5. [PyPy](#pypy)
4. [Software Architecture](#software-architecture)
5. [`protonet-networks`](#protonet-networks)
    
# Overview

DreamCoder is a wake-sleep algorithm that finds programs to solve a given set of tasks in a particular domain.

# Getting Started

This section will provide the basic information necessary to run DreamCoder.

## Usage

### Getting the code

Clone the codebase and its submodules.

The codebase has several git submodule dependencies.

If you’ve already cloned the repo and did not clone the submodules, run:
```
git submodule update --recursive --init
```

### Running using Singularity

If you don't want to manually install all the of the software dependencies locally you can instead use a singularity container. To build the container, you can use the recipe `singularity` in the repository, and run the following from the root directory of the repository (tested using singularity version 2.5):
```
sudo singularity build container.img singularity
```
Then run the following to open a shell in the container environment:
```
./container.img
```
Alternatively, one can run tasks within the container via the `singularity` command:
```
singularity exec container.img  python text.py <commandline arguments>
```

### Running tasks from the commandline

The codebase has a few scripts already defined for running tasks for a particular domain located in the `bin/` directory.

The general usage pattern is to run the script from the root of the repo as follows:
```
python bin/text.py <commandline arguments>
```

For example, see the following modules:
 * `bin/text.py` - trains the system on automatically generated text-editing tasks.
 * `bin/list.py` - trains the system on automatically generated list processing tasks.
 * `bin/logo.py`
 * `bin/tower.py`

In general, the scripts should specify the commandline options if you run the script with `--help`:
```
python bin/list.py --help
```

An example training task command might be:
```
python text.py -t 20 -RS 5000
```
This runs with an enumeration timeout and recognition timeout of 20 seconds (since recognition timeout defaults to enumeration timeout if `-R` is not provided) and 5000 recognition steps.

Use the `--testingTimeout` flag to ensure the testing tasks are run. Otherwise, they will be skipped.

See more examples of commands in the `docs/official_experiments` file.

### Understanding console output

The first output of the DreamCoder scripts - after some commandline debugging statements - is typically output from launching tasks, and will appear as follows:
```
(python) Launching list(int) -> list(int) (1 tasks) w/ 1 CPUs. 15.000000 <= MDL < 16.500000. Timeout 10.201876.
(python) Launching list(int) -> list(int) (1 tasks) w/ 1 CPUs. 15.000000 <= MDL < 16.500000. Timeout 9.884262.
(python) Launching list(int) -> list(int) (1 tasks) w/ 1 CPUs. 15.000000 <= MDL < 16.500000. Timeout 2.449733.
	(ocaml: 1 CPUs. shatter: 1. |fringe| = 1. |finished| = 0.)
	(ocaml: 1 CPUs. shatter: 1. |fringe| = 1. |finished| = 0.)
(python) Launching list(int) -> list(int) (1 tasks) w/ 1 CPUs. 15.000000 <= MDL < 16.500000. Timeout 4.865186.
	(ocaml: 1 CPUs. shatter: 1. |fringe| = 1. |finished| = 0.)
```
MDL corresponds to the space used for the definition language to store the program expressions. The MDL can be tuned by changing the `-t` timeout option, which will alter the length of time the algorithm runs as well as its performance in solving tasks.

The next phase of the script will show whether the algorithm is able to match programs to tasks. A `HIT` indicates a match and  a `MISS` indicates a failure to find a suitable program for a task:
```
Generative model enumeration results:
HIT sum w/ (lambda (fold $0 0 (lambda (lambda (+ $0 $1))))) ; log prior = -5.545748 ; log likelihood = 0.000000
HIT take-k with k=2 w/ (lambda (cons (car $0) (cons (car (cdr $0)) empty))) ; log prior = -10.024556 ; log likelihood = 0.000000
MISS take-k with k=3
MISS remove eq 3
MISS keep gt 3
MISS remove gt 3
Hits 2/6 tasks
```

The program output also contains some information about the programs that the algorithm is trying to solve each task with:
```
Showing the top 5 programs in each frontier being sent to the compressor:
add1
0.00    (lambda (incr $0))

add2
-0.29   (lambda (incr2 $0))
-1.39   (lambda (incr (incr $0)))

add3
-0.85   (lambda (incr (incr2 $0)))
-0.85   (lambda (incr2 (incr $0)))
-1.95   (lambda (incr (incr (incr $0))))
```

The program will cycle through multiple iterations of wake and sleep phases (controlled by the `-i` flag). It is worth noting that after each iteration the scripts will export checkpoint files in Python's "pickle" data format.
```
Exported checkpoint to experimentOutputs/demo/2019-06-06T18:00:38.264452_aic=1.0_arity=3_ET=2_it=2_MF=10_noConsolidation=False_pc=30.0_RW=False_solver=ocaml_STM=True_L=1.0_TRR=default_K=2_topkNotMAP=False_rec=False.pickle
```

These pickle checkpoint files are input to another script that can graph the results of the algorithm, which will be discussed in the next section.

### Graphing the results

The `bin/graphs.py` script can be used to graph the results of the program's output, which can be much easier than trying to interpret the pickle files and console output.

An example invocation is as follows:
```
python bin/graphs.py --checkpoints <pickle_file> --export test.png
```
The script takes a path to a pickle file and an export path for the image the graph will be saved at.

Here's an example of the output:
![example output](./docs/example.png "Example Results")

This script has a number of other options which can be viewed via the `--help` command.

See the [Installing Python dependencies](#installing-python-dependencies) section below if the `bin/graphs.py` script is complaining about missing dependencies.

Also the following error occurs if in some cases:
```
feh ERROR: Can't open X display. It *is* running, yeah?
```
If you see that error, you can run this in your terminal before running `graphs.py` to fix the issue:
```
export DISPLAY=:0
```

## Additional Information

This section includes additional information, such as the steps to rebuild the OCaml binaries, or extend DreamCoder to solve new problems in new domains.

### Creating new domains

To create new domains of problems to solve, a number of things must be done. Follow the steps in [Creating New Domains](./docs/creating-new-domains.md) to get started.

Note that after a new domain is created, if any of the OCaml code has been edited it is required that you rebuild the OCaml binaries. See [Building the OCaml binaries](#building-the-ocaml-binaries) for more info.

### Installing Python dependencies

It's useful to install the Python dependencies in case you want to run certain scripts (e.g. `bin/graphs.py`) from your local machine.

To install Python dependencies, activate a virtual environment (or don't) and run:
```
pip install -r requirements.txt
```

For macOS, there are some additional system dependencies required to install these libraries in `requirements.txt`. To install these system dependencies locally, you can use homebrew to download them:
```
brew install swig
brew install libomp
brew cask install xquartz
brew install feh
brew install imagemagick
```

### Building the OCaml binaries

If you introduce new primitives for new domains of tasks, or modify the OCaml codebase (in `solvers/`) for any reason, you will need to rebuild the OCaml binaries before rerunning the Python scripts.

To rebuild the OCaml binaires, run the following from the root of the repo:
```
make clean
make
```

If you are not running within the singularity container, you will need to install the OCaml libraries dependencies first. Currently, in order to build the solver on a fresh opam switch, the following packages (anecdotal data from Arch x64, assuming you have `opam`) are required:
```bash
opam update                 # Seriously, do that one
opam switch 4.06.1+flambda  # caml.inria.fr/pub/docs/manual-ocaml/flambda.html
eval `opam config env`      # *sight*
opam install ppx_jane core re2 yojson vg cairo2 camlimages menhir ocaml-protoc zmq
```

Now try to run `make` in the root folder, it should build several ocaml
binaries.

### Build rust compressor

Get Rust (e.g. `curl https://sh.rustup.rs -sSf | sh` according to
[https://www.rust-lang.org/](https://www.rust-lang.org/en-US/install.html))

Now running make in the `rust_compressor` folder should install the right
packages and build the binary.

### PyPy

If for some reason you want to run something in pypy, install it from:
```
https://github.com/squeaky-pl/portable-pypy#portable-pypy-distribution-for-linux
```
Be sure to add `pypy3` to the path. Really though you should try to
use the rust compressor and the ocaml solver. You will have to
(annoyingly) install parallel libraries on the pypy side even if you
have them installed on the Python side:

```
pypy3 -m ensurepip
pypy3 -m pip install --user vmprof
pypy3 -m pip install --user dill
pypy3 -m pip install --user psutil
```

## Software Architecture

To better understand how dreamcoder works under the hood, see the [Software Architecture](./docs/software-architecture.md) document.

## `protonet-networks`

### Credit of (most of) the `protonet` code

The `protonet-networks` folder contains some modifications over a big chunk of
code from [this repository](https://github.com/jakesnell/prototypical-networks), here is the attribution information :

> Code for the NIPS 2017 paper [Prototypical Networks for Few-shot Learning](http://papers.nips.cc/paper/6996-prototypical-networks-for-few-shot-learning.pdf)

If you use that part of the code, please cite their paper, and check out
what they did:

```bibtex
@inproceedings{snell2017prototypical,
  title={Prototypical Networks for Few-shot Learning},
  author={Snell, Jake and Swersky, Kevin and Zemel, Richard},
  booktitle={Advances in Neural Information Processing Systems},
  year={2017}
}
```

### LICENSE of `protonets-networks` folder

MIT License

Copyright (c) 2017 Jake Snell

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
