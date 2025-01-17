# Makefile for py-web-tool.
# Requires a pyweb-3.0.py (untouched) to bootstrap the current version.

SOURCE_PYLPWEB = src/pyweb.w src/intro.w src/overview.w src/impl.w src/tests.w src/todo.w src/done.w src/language.w src/usage.w
TEST_PYLPWEB = tests/pyweb_test.w tests/intro.w tests/unit.w tests/func.w tests/scripts.w	
EXAMPLES_PYLPWEB = examples/hello_world_latex.w examples/hello_world_rst.w ackermanns.w
DOCUTILS_PYLPWEB = docutils.conf pyweb.css page-layout.css

.PHONY : test

# Note the bootstrapping new version from version 3.0 as baseline.
# Handy to keep this *outside* the project's Git repository.
# Note that the bootstrap 3.0 version doesn't support the -o option.
PYLPWEB_BOOTSTRAP=${PWD}/bootstrap/pyweb.py

test : $(SOURCE_PYLPWEB) $(TEST_PYLPWEB)
	cd src && python3 $(PYLPWEB_BOOTSTRAP) -xw pyweb.w 
	python3 src/pyweb.py tests/pyweb_test.w -o tests
	PYTHONPATH=${PWD}/src pytest
	python3 src/pyweb.py tests/pyweb_test.w -xt -o tests
	rst2html.py tests/pyweb_test.rst tests/pyweb_test.html
	mypy --strict --show-error-codes src

doc : src/pyweb.html

build : src/pyweb.py src/tangle.py src/weave.py src/pyweb.html

examples : examples/hello_world_latex.tex examples/hello_world_rst.html examples/ackermanns.html

src/pyweb.py src/pyweb.rst : $(SOURCE_PYLPWEB)
	cd src && python3 $(PYLPWEB_BOOTSTRAP) pyweb.w 

src/pyweb.html : src/pyweb.rst $(DOCUTILS_PYLPWEB)
	rst2html.py $< $@
         
tests/pyweb_test.rst : src/pyweb.py $(TEST_PYLPWEB)
	python3 src/pyweb.py tests/pyweb_test.w -o tests

tests/pyweb_test.html : tests/pyweb_test.rst $(DOCUTILS_PYLPWEB)
	rst2html.py $< $@

examples/hello_world_rst.rst : examples/hello_world_rst.w
	python3 src/pyweb.py -w rst examples/hello_world_rst.w -o examples

examples/hello_world_rst.html : examples/hello_world_rst.rst $(DOCUTILS_PYLPWEB)
	rst2html.py $< $@

examples/hello_world_latex.tex : examples/hello_world_latex.w
	python3 src/pyweb.py -w latex examples/hello_world_latex.w -o examples

examples/ackermanns.rst : examples/ackermanns.w
	python3 src/pyweb.py -w rst examples/ackermanns.w -o examples
	python -m doctest examples/ackermanns.py

examples/ackermanns.html : examples/ackermanns.rst $(DOCUTILS_PYLPWEB)
	rst2html.py $< $@
