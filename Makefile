all:
	rm -f data/geom/logoDrawString
	cd solvers && \
	  dune build solver.exe && \
	  dune build versionDemo.exe && \
	  dune build helmholtz.exe && \
	  dune build logoDrawString.exe && \
	  dune build protonet-tester.exe && \
	  dune build compression.exe && \
	  cp _build/default/compression.exe ../compression && \
	  cp _build/default/versionDemo.exe ../versionDemo && \
	  cp _build/default/solver.exe ../solver && \
	  cp _build/default/helmholtz.exe ../helmholtz && \
	  cp _build/default/protonet-tester.exe ../protonet-tester && \
	  cp _build/default/logoDrawString.exe \
	    ../logoDrawString && \
	  ln -s ../../logoDrawString \
	    ../data/geom/logoDrawString

clean:
	cd solvers && dune clean
	rm -f solver
	rm -f compression
	rm -f helmholtz
	rm -f logoDrawString
	rm -f data/geom/logoDrawString
