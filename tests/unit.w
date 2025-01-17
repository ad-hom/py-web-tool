Unit Testing
============

..    test/func.w 

There are several broad areas of unit testing.  There are the 34 classes in this application.
However, it isn't really necessary to test everyone single one of these classes.
We'll decompose these into several hierarchies.


-    Emitters
    
        class Emitter:  
        
        class Weaver(Emitter):  
        
        class LaTeX(Weaver):  
        
        class HTML(Weaver):  
        
        class HTMLShort(HTML):  
        
        class Tangler(Emitter):  
        
        class TanglerMake(Tangler):  
    
    
-    Structure: Chunk, Command
    
        class Chunk:  
        
        class NamedChunk(Chunk):  

        class NamedChunk_Noindent(Chunk):  
        
        class OutputChunk(NamedChunk):  
        
        class NamedDocumentChunk(NamedChunk):  
                
        class Command:  
        
        class TextCommand(Command):  
        
        class CodeCommand(TextCommand):  
        
        class XrefCommand(Command):  
        
        class FileXrefCommand(XrefCommand):  
        
        class MacroXrefCommand(XrefCommand):  
        
        class UserIdXrefCommand(XrefCommand):  
        
        class ReferenceCommand(Command):  
    
    
-    class Error(Exception):   
    
-    Reference Handling
    
        class Reference:  
        
        class SimpleReference(Reference):  
        
        class TransitiveReference(Reference):  
    
    
-    class Web:  

-    class WebReader:  

        class Tokenizer:
        
        class OptionParser:
    
-    Action
    
        class Action:  
        
        class ActionSequence(Action):  
        
        class WeaveAction(Action):  
        
        class TangleAction(Action):  
        
        class LoadAction(Action):  
    
    
-    class Application:  
    
-    class MyWeaver(HTML):  
    
-    class MyHTML(pyweb.HTML):


This gives us the following outline for unit testing.

@o test_unit.py 
@{@<Unit Test overheads: imports, etc.@>
@<Unit Test of Emitter class hierarchy@>
@<Unit Test of Chunk class hierarchy@>
@<Unit Test of Command class hierarchy@>
@<Unit Test of Reference class hierarchy@>
@<Unit Test of Web class@>
@<Unit Test of WebReader class@>
@<Unit Test of Action class hierarchy@>
@<Unit Test of Application class@>
@<Unit Test main@>
@}

Emitter Tests
-------------

The emitter class hierarchy produces output files; either woven output
which uses templates to generate proper markup, or tangled output which
precisely follows the document structure.


@d Unit Test of Emitter class hierarchy... @{
@<Unit Test Mock Chunk class@>
@<Unit Test of Emitter Superclass@>
@<Unit Test of Weaver subclass of Emitter@>
@<Unit Test of LaTeX subclass of Emitter@>
@<Unit Test of HTML subclass of Emitter@>
@<Unit Test of HTMLShort subclass of Emitter@>
@<Unit Test of Tangler subclass of Emitter@>
@<Unit Test of TanglerMake subclass of Emitter@>
@}

The Emitter superclass is designed to be extended.  The test 
creates a subclass to exercise a few key features. The default
emitter is Tangler-like.

@d Unit Test of Emitter Superclass... @{ 
class EmitterExtension(pyweb.Emitter):
    def doOpen(self) -> None:
        self.theFile = io.StringIO()
    def doClose(self) -> None:
        self.theFile.flush()
        
class TestEmitter(unittest.TestCase):
    def setUp(self) -> None:
        self.emitter = EmitterExtension()
    def test_emitter_should_open_close_write(self) -> None:
        self.emitter.open(Path("test.tmp"))
        self.emitter.write("Something")
        self.emitter.close()
        self.assertEqual("Something", self.emitter.theFile.getvalue())
    def test_emitter_should_codeBlock(self) -> None:
        self.emitter.open(Path("test.tmp"))
        self.emitter.codeBlock("Some")
        self.emitter.codeBlock(" Code")
        self.emitter.close()
        self.assertEqual("Some Code\n", self.emitter.theFile.getvalue())
    def test_emitter_should_indent(self) -> None:
        self.emitter.open(Path("test.tmp"))
        self.emitter.codeBlock("Begin\n")
        self.emitter.addIndent(4)
        self.emitter.codeBlock("More Code\n")
        self.emitter.clrIndent()
        self.emitter.codeBlock("End")
        self.emitter.close()
        self.assertEqual("Begin\n    More Code\nEnd\n", self.emitter.theFile.getvalue())
    def test_emitter_should_noindent(self) -> None:
        self.emitter.open(Path("test.tmp"))
        self.emitter.codeBlock("Begin\n")
        self.emitter.setIndent(0)
        self.emitter.codeBlock("More Code\n")
        self.emitter.clrIndent()
        self.emitter.codeBlock("End")
        self.emitter.close()
        self.assertEqual("Begin\nMore Code\nEnd\n", self.emitter.theFile.getvalue())
@}

A mock Chunk is a Chunk-like object that we can use to test Weavers.

Some tests will create multiple chunks. To keep their state separate,
we define a function to return each mocked ``Chunk`` instance as a new Mock
object. The overall ``MockChunk`` class, uses a side effect to 
invoke the the ``mock_chunk_instance()`` function.

The ``write_closure()`` is a function that calls the ``Tangler.write()`` 
method. This is *not* consistent with best unit testing practices.
It is merely a hold-over from an older testing strategy. The mock call
history to the ``tangle()`` method of each ``Chunk`` instance is a better
test strategy. 


@d Unit Test Mock Chunk...
@{
def mock_chunk_instance(name: str, seq: int, lineNumber: int) -> Mock:
    def write_closure(aWeb: pyweb.Web, aTangler: pyweb.Tangler) -> None:
        aTangler.write(name)
        
    chunk = Mock(
        wraps=pyweb.Chunk,
        fullName=name,
        seq=seq,
        lineNumber=lineNumber,
        initial=True,
        commands=[],
        referencedBy=[],
        references=Mock(return_value=[]),
        reference_indent=Mock(),
        reference_dedent=Mock(),
        tangle=Mock(side_effect=write_closure)
    )
    chunk.name=name
    return chunk
    
MockChunk = Mock(
    name="Chunk class",
    side_effect=mock_chunk_instance
)
@}

The default Weaver is an Emitter that uses templates to produce RST markup.

@d Unit Test of Weaver... @{
class TestWeaver(unittest.TestCase):
    def setUp(self) -> None:
        self.weaver = pyweb.Weaver()
        self.weaver.reference_style = pyweb.SimpleReference() 
        self.filepath = Path("testweaver") 
        self.aFileChunk = MockChunk("File", 123, 456)
        self.aFileChunk.referencedBy = []
        self.aChunk = MockChunk("Chunk", 314, 278)
        self.aChunk.referencedBy = [self.aFileChunk]
        self.aChunk.references.return_value=[(self.aFileChunk.name, self.aFileChunk.seq)]
        
    def tearDown(self) -> None:
        try:
            self.filepath.with_suffix('.rst').unlink()
        except OSError:
            pass
        
    def test_weaver_functions_generic(self) -> None:
        result = self.weaver.quote("|char| `code` *em* _em_")
        self.assertEqual(r"\|char\| \`code\` \*em\* \_em\_", result)
        result = self.weaver.references(self.aChunk)
        self.assertEqual("File (`123`_)", result)
        result = self.weaver.referenceTo("Chunk", 314)
        self.assertEqual(r"|srarr|\ Chunk (`314`_)", result)
        self.assertEqual(self.aFileChunk.mock_calls, [])
        self.assertEqual(self.aChunk.mock_calls, [call.references(self.weaver)])
  
    def test_weaver_should_codeBegin(self) -> None:
        self.weaver.open(self.filepath)
        self.weaver.addIndent()
        self.weaver.codeBegin(self.aChunk)
        self.weaver.codeBlock(self.weaver.quote("*The* `Code`\n"))
        self.weaver.clrIndent()
        self.weaver.codeEnd(self.aChunk)
        self.weaver.close()
        txt = self.filepath.with_suffix(".rst").read_text()
        self.assertEqual("\n..  _`314`:\n..  rubric:: Chunk (314) =\n..  parsed-literal::\n    :class: code\n\n    \\*The\\* \\`Code\\`\n\n..\n\n    ..  class:: small\n\n        |loz| *Chunk (314)*. Used by: File (`123`_)\n", txt)
  
    def test_weaver_should_fileBegin(self) -> None:
        self.weaver.open(self.filepath)
        self.weaver.fileBegin(self.aFileChunk)
        self.weaver.codeBlock(self.weaver.quote("*The* `Code`\n"))
        self.weaver.fileEnd(self.aFileChunk)
        self.weaver.close()
        txt = self.filepath.with_suffix(".rst").read_text()
        self.assertEqual("\n..  _`123`:\n..  rubric:: File (123) =\n..  parsed-literal::\n    :class: code\n\n    \\*The\\* \\`Code\\`\n\n..\n\n    ..  class:: small\n\n        |loz| *File (123)*.\n", txt)

    def test_weaver_should_xref(self) -> None:
        self.weaver.open(self.filepath)
        self.weaver.xrefHead( )
        self.weaver.xrefLine("Chunk", [ ("Container", 123) ])
        self.weaver.xrefFoot( )
        #self.weaver.fileEnd(self.aFileChunk) # Why?
        self.weaver.close()
        txt = self.filepath.with_suffix(".rst").read_text()
        self.assertEqual("\n:Chunk:\n    |srarr|\\ (`('Container', 123)`_)\n\n", txt)

    def test_weaver_should_xref_def(self) -> None:
        self.weaver.open(self.filepath)
        self.weaver.xrefHead( )
        # Seems to have changed to a simple list of lines??
        self.weaver.xrefDefLine("Chunk", 314, [ 123, 567 ])
        self.weaver.xrefFoot( )
        #self.weaver.fileEnd(self.aFileChunk) # Why?
        self.weaver.close()
        txt = self.filepath.with_suffix(".rst").read_text()
        self.assertEqual("\n:Chunk:\n    `123`_ [`314`_] `567`_\n\n", txt)
@}

A significant fraction of the various subclasses of weaver are simply
expansion of templates.  There's no real point in testing the template
expansion, since that's more easily tested by running a document
through pyweb and looking at the results.

We'll examine a few features of the LaTeX templates.

@d Unit Test of LaTeX... @{ 
class TestLaTeX(unittest.TestCase):
    def setUp(self) -> None:
        self.weaver = pyweb.LaTeX()
        self.weaver.reference_style = pyweb.SimpleReference() 
        self.filepath = Path("testweaver") 
        self.aFileChunk = MockChunk("File", 123, 456)
        self.aFileChunk.referencedBy = [ ]
        self.aChunk = MockChunk("Chunk", 314, 278)
        self.aChunk.referencedBy = [self.aFileChunk,]
        self.aChunk.references.return_value=[(self.aFileChunk.name, self.aFileChunk.seq)]

    def tearDown(self) -> None:
        try:
            self.filepath.with_suffix(".tex").unlink()
        except OSError:
            pass
            
    def test_weaver_functions_latex(self) -> None:
        result = self.weaver.quote("\\end{Verbatim}")
        self.assertEqual("\\end\\,{Verbatim}", result)
        result = self.weaver.references(self.aChunk)
        expected = textwrap.indent(
            textwrap.dedent("""
                \\footnotesize
                Used by:
                \\begin{list}{}{}
                    
                \\item Code example File (123) (Sect. \\ref{pyweb123}, p. \\pageref{pyweb123})
                
                \\end{list}
                \\normalsize
            """), 
        '    ')
        self.assertEqual(rstrip_lines(expected), rstrip_lines(result))
        result = self.weaver.referenceTo("Chunk", 314)
        self.assertEqual("$\\triangleright$ Code Example Chunk (314)", result)
        self.assertEqual(self.aFileChunk.mock_calls, [])
        self.assertEqual(self.aChunk.mock_calls, [call.references(self.weaver)])
@}

We'll examine a few features of the HTML templates.

@d Unit Test of HTML subclass... @{ 
class TestHTML(unittest.TestCase):
    def setUp(self) -> None:
        self.weaver = pyweb.HTML( )
        self.weaver.reference_style = pyweb.SimpleReference() 
        self.filepath = Path("testweaver") 
        self.aFileChunk = MockChunk("File", 123, 456)
        self.aFileChunk.referencedBy = []
        self.aChunk = MockChunk("Chunk", 314, 278)
        self.aChunk.referencedBy = [self.aFileChunk,]
        self.aChunk.references.return_value=[(self.aFileChunk.name, self.aFileChunk.seq)]

    def tearDown(self) -> None:
        try:
            self.filepath.with_suffix(".html").unlink()
        except OSError:
            pass
            
    def test_weaver_functions_html(self) -> None:
        result = self.weaver.quote("a < b && c > d")
        self.assertEqual("a &lt; b &amp;&amp; c &gt; d", result)
        result = self.weaver.references(self.aChunk)
        self.assertEqual('  Used by <a href="#pyweb123"><em>File</em>&nbsp;(123)</a>.', result)
        result = self.weaver.referenceTo("Chunk", 314)
        self.assertEqual('<a href="#pyweb314">&rarr;<em>Chunk</em> (314)</a>', result)
        self.assertEqual(self.aFileChunk.mock_calls, [])
        self.assertEqual(self.aChunk.mock_calls, [call.references(self.weaver)])

@}

The unique feature of the ``HTMLShort`` class is a template change.

    **TODO:** Test ``HTMLShort``.

@d Unit Test of HTMLShort subclass... @{# TODO: Finish this@}

A Tangler emits the various named source files in proper format for the desired
compiler and language.

@d Unit Test of Tangler subclass... 
@{ 
class TestTangler(unittest.TestCase):
    def setUp(self) -> None:
        self.tangler = pyweb.Tangler()
        self.filepath = Path("testtangler.code") 
        self.aFileChunk = MockChunk("File", 123, 456)
        #self.aFileChunk.references_list = [ ]
        self.aChunk = MockChunk("Chunk", 314, 278)
        #self.aChunk.references_list = [ ("Container", 123) ]
    def tearDown(self) -> None:
        try:
            self.filepath.unlink()
        except FileNotFoundError:
            pass
        
    def test_tangler_functions(self) -> None:
        result = self.tangler.quote(string.printable)
        self.assertEqual(string.printable, result)
        
    def test_tangler_should_codeBegin(self) -> None:
        self.tangler.open(self.filepath)
        self.tangler.codeBegin(self.aChunk)
        self.tangler.codeBlock(self.tangler.quote("*The* `Code`\n"))
        self.tangler.codeEnd(self.aChunk)
        self.tangler.close()
        txt = self.filepath.read_text()
        self.assertEqual("*The* `Code`\n", txt)
@}

A TanglerMake uses a cheap hack to see if anything changed.
It creates a temporary file and then does a complete (slow, expensive) file difference
check.  If the file is different, the old version is replaced with 
the new version.  If the file content is the same, the old version
is left intact with all of the operating system creation timestamps
untouched.




@d Unit Test of TanglerMake subclass... @{
class TestTanglerMake(unittest.TestCase):
    def setUp(self) -> None:
        self.tangler = pyweb.TanglerMake()
        self.filepath = Path("testtangler.code") 
        self.aChunk = MockChunk("Chunk", 314, 278)
        #self.aChunk.references_list = [("Container", 123)]
        self.tangler.open(self.filepath)
        self.tangler.codeBegin(self.aChunk)
        self.tangler.codeBlock(self.tangler.quote("*The* `Code`\n"))
        self.tangler.codeEnd(self.aChunk)
        self.tangler.close()
        self.time_original = self.filepath.stat().st_mtime
        self.original = self.filepath.stat()
        
    def tearDown(self) -> None:
        try:
            self.filepath.unlink()
        except OSError:
            pass
        
    def test_same_should_leave(self) -> None:
        self.tangler.open(self.filepath)
        self.tangler.codeBegin(self.aChunk)
        self.tangler.codeBlock(self.tangler.quote("*The* `Code`\n"))
        self.tangler.codeEnd(self.aChunk)
        self.tangler.close()
        self.assertTrue(os.path.samestat(self.original, self.filepath.stat()))
        #self.assertEqual(self.time_original, self.filepath.stat().st_mtime)
        
    def test_different_should_update(self) -> None:
        self.tangler.open(self.filepath)
        self.tangler.codeBegin(self.aChunk)
        self.tangler.codeBlock(self.tangler.quote("*Completely Different* `Code`\n"))
        self.tangler.codeEnd(self.aChunk)
        self.tangler.close()
        self.assertFalse(os.path.samestat(self.original, self.filepath.stat()))
        #self.assertNotEqual(self.time_original, self.filepath.stat().st_mtime)
@}

Chunk Tests
------------

The Chunk and Command class hierarchies model the input document -- the web
of chunks that are used to produce the documentation and the source files.


@d Unit Test of Chunk class hierarchy... 
@{
@<Unit Test of Chunk superclass@>
@<Unit Test of NamedChunk subclass@>
@<Unit Test of NamedChunk_Noindent subclass@>
@<Unit Test of OutputChunk subclass@>
@<Unit Test of NamedDocumentChunk subclass@>
@}

In order to test the Chunk superclass, we need several mock objects.
A Chunk contains one or more commands.  A Chunk is a part of a Web.
Also, a Chunk is processed by a Tangler or a Weaver.  We'll need 
mock objects for all of these relationships in which a Chunk participates.

A MockCommand can be attached to a Chunk.

@d Unit Test of Chunk superclass...
@{
MockCommand = Mock(
    name="Command class",
    side_effect=lambda: Mock(
        name="Command instance",
        # text="",  # Only used for TextCommand.
        lineNumber=314,
        startswith=Mock(return_value=False)
    )
)
@}

A MockWeb can contain a Chunk.

@d Unit Test of Chunk superclass...
@{

def mock_web_instance() -> Mock:
    web = Mock(
        name="Web instance",
        chunks=[],
        add=Mock(return_value=None),
        addNamed=Mock(return_value=None),
        addOutput=Mock(return_value=None),
        fullNameFor=Mock(side_effect=lambda name: name),
        fileXref=Mock(return_value={'file': [1,2,3]}),
        chunkXref=Mock(return_value={'chunk': [4,5,6]}),
        userNamesXref=Mock(return_value={'name': (7, [8,9,10])}),
        getchunk=Mock(side_effect=lambda name: [MockChunk(name, 1, 314)]),
        createUsedBy=Mock(),
        weaveChunk=Mock(side_effect=lambda name, weaver: weaver.write(name)),
        weave=Mock(return_value=None),
        tangle=Mock(return_value=None),
    )
    return web

MockWeb = Mock(
    name="Web class",
    side_effect=mock_web_instance
)
@}

A MockWeaver or MockTangler appear to process a Chunk.
We can interrogate the ``mock_calls`` to be sure the right things were done.

We need to permit ``__enter__()`` and ``__exit__()``,
which leads to a multi-step instance.
The initial instance with ``__enter__()`` that
returns the context manager instance.


@d Unit Test of Chunk superclass...
@{
def mock_weaver_instance() -> MagicMock:
    context = MagicMock(
        name="Weaver instance context",
        __exit__=Mock()
    )
    
    weaver = MagicMock(
        name="Weaver instance",
        quote=Mock(return_value="quoted"),
        __enter__=Mock(return_value=context)
    )
    return weaver

MockWeaver = Mock(
    name="Weaver class",
    side_effect=mock_weaver_instance
)

def mock_tangler_instance() -> MagicMock:
    context = MagicMock(
        name="Tangler instance context",
        __exit__=Mock()
    )
    
    tangler = MagicMock(
        name="Tangler instance",
        __enter__=Mock(return_value=context)
    )
    return tangler

MockTangler = Mock(
    name="Tangler class",
    side_effect=mock_tangler_instance
)

@}

A Chunk is built, interrogated and then emitted.

@d Unit Test of Chunk superclass...
@{
class TestChunk(unittest.TestCase):
    def setUp(self) -> None:
        self.theChunk = pyweb.Chunk()
        
    @<Unit Test of Chunk construction@>
    
    @<Unit Test of Chunk interrogation@>
    
    @<Unit Test of Chunk emission@>
@}

Can we build a Chunk?

@d Unit Test of Chunk construction...
@{
def test_append_command_should_work(self) -> None:
    cmd1 = MockCommand()
    self.theChunk.append(cmd1)
    self.assertEqual(1, len(self.theChunk.commands))
    self.assertEqual(cmd1.chunk, self.theChunk)
    
    cmd2 = MockCommand()
    self.theChunk.append(cmd2)
    self.assertEqual(2, len(self.theChunk.commands))
    self.assertEqual(cmd2.chunk, self.theChunk)

def test_append_initial_and_more_text_should_work(self) -> None:
    self.theChunk.appendText("hi mom")
    self.assertEqual(1, len(self.theChunk.commands))
    self.theChunk.appendText("&more text")
    self.assertEqual(1, len(self.theChunk.commands))
    self.assertEqual("hi mom&more text", self.theChunk.commands[0].text)
    
def test_append_following_text_should_work(self) -> None:
    cmd1 = MockCommand()
    self.theChunk.append(cmd1)
    self.theChunk.appendText("hi mom")
    self.assertEqual(2, len(self.theChunk.commands))
    assert cmd1.chunk == self.theChunk

def test_append_chunk_to_web_should_work(self) -> None:
    web = MockWeb()
    self.theChunk.webAdd(web)
    self.assertEqual(web.add.mock_calls, [call(self.theChunk)])
@}

Can we interrogate a Chunk?

@d Unit Test of Chunk interrogation...
@{
def test_leading_command_should_not_find(self) -> None:
    self.assertFalse(self.theChunk.startswith("hi mom"))
    cmd1 = MockCommand()
    self.theChunk.append(cmd1)
    self.assertFalse(self.theChunk.startswith("hi mom"))
    self.theChunk.appendText("hi mom")
    self.assertEqual(2, len(self.theChunk.commands) )
    self.assertFalse(self.theChunk.startswith("hi mom"))
    
def test_leading_text_should_not_find(self) -> None:
    self.assertFalse(self.theChunk.startswith("hi mom"))
    self.theChunk.appendText("hi mom")
    self.assertTrue(self.theChunk.startswith("hi mom"))
    cmd1 = MockCommand()
    self.theChunk.append(cmd1)
    self.assertTrue(self.theChunk.startswith("hi mom"))
    self.assertEqual(2, len(self.theChunk.commands) )

def test_regexp_exists_should_find(self) -> None:
    self.theChunk.appendText("this chunk has many words")
    pat = re.compile(r"\Wchunk\W")
    found = self.theChunk.searchForRE(pat)
    self.assertTrue(found is self.theChunk)
    
def test_regexp_missing_should_not_find(self):
    self.theChunk.appendText("this chunk has many words")
    pat = re.compile(r"\Warpigs\W")
    found = self.theChunk.searchForRE(pat)
    self.assertTrue(found is None)
    
def test_lineNumber_should_work(self) -> None:
    self.assertTrue(self.theChunk.lineNumber is None)
    cmd1 = MockCommand()
    self.theChunk.append(cmd1)
    self.assertEqual(314, self.theChunk.lineNumber)
@}

Can we emit a Chunk with a weaver or tangler?

@d Unit Test of Chunk emission...
@{
def test_weave_chunk_should_work(self) -> None:
    wvr = MockWeaver()
    web = MockWeb()
    self.theChunk.appendText("this chunk has very & many words")
    self.theChunk.weave(web, wvr)
    self.assertEqual(wvr.docBegin.mock_calls, [call(self.theChunk)])
    self.assertEqual(wvr.write.mock_calls, [call("this chunk has very & many words")])
    self.assertEqual(wvr.docEnd.mock_calls, [call(self.theChunk)])
    
def test_tangle_should_fail(self) -> None:
    tnglr = MockTangler()
    web = MockWeb()
    self.theChunk.appendText("this chunk has very & many words")
    try:
        self.theChunk.tangle(web, tnglr)
        self.fail()
    except pyweb.Error as e:
        self.assertEqual("Cannot tangle an anonymous chunk", e.args[0])
@}

The ``NamedChunk`` is created by a ``@@d`` command.
Since it's named, it appears in the Web's index.  Also, it is woven
and tangled differently than anonymous chunks.

@d Unit Test of NamedChunk subclass... @{ 
class TestNamedChunk(unittest.TestCase):
    def setUp(self) -> None:
        self.theChunk = pyweb.NamedChunk("Some Name...")
        cmd = self.theChunk.makeContent("the words & text of this Chunk")
        self.theChunk.append(cmd)
        self.theChunk.setUserIDRefs("index terms")
        
    def test_should_find_xref_words(self) -> None:
        self.assertEqual(2, len(self.theChunk.getUserIDRefs()))
        self.assertEqual("index", self.theChunk.getUserIDRefs()[0])
        self.assertEqual("terms", self.theChunk.getUserIDRefs()[1])
        
    def test_append_named_chunk_to_web_should_work(self) -> None:
        web = MockWeb()
        self.theChunk.webAdd(web)
        self.assertEqual(web.addNamed.mock_calls, [call(self.theChunk)])

    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.theChunk.weave(web, wvr)
        self.assertEqual(wvr.codeBegin.mock_calls, [call(self.theChunk)])
        self.assertEqual(wvr.quote.mock_calls, [call('the words & text of this Chunk')])
        self.assertEqual(wvr.codeBlock.mock_calls, [call('quoted')])
        self.assertEqual(wvr.codeEnd.mock_calls, [call(self.theChunk)])

    def test_tangle_should_work(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        self.theChunk.tangle(web, tnglr)
        self.assertEqual(tnglr.codeBegin.mock_calls, [call(self.theChunk)])
        self.assertEqual(tnglr.codeBlock.mock_calls, [call("the words & text of this Chunk")])
        self.assertEqual(tnglr.codeEnd.mock_calls, [call(self.theChunk)])      
@}

@d Unit Test of NamedChunk_Noindent subclass...
@{
class TestNamedChunk_Noindent(unittest.TestCase):
    def setUp(self) -> None:
        self.theChunk = pyweb.NamedChunk_Noindent("NoIndent Name...")
        cmd = self.theChunk.makeContent("the words & text of this Chunk")
        self.theChunk.append(cmd)
        self.theChunk.setUserIDRefs("index terms")
    def test_tangle_should_work(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        self.theChunk.tangle(web, tnglr)

        self.assertEqual(tnglr.mock_calls, [
                call.codeBegin(self.theChunk),
                call.codeBlock('the words & text of this Chunk'),
                call.codeEnd(self.theChunk)
            ]
        )
@}


The ``OutputChunk`` is created by a ``@@o`` command.
Since it's named, it appears in the Web's index.  Also, it is woven
and tangled differently than anonymous chunks.

@d Unit Test of OutputChunk subclass... @{
class TestOutputChunk(unittest.TestCase):
    def setUp(self) -> None:
        self.theChunk = pyweb.OutputChunk("filename", "#", "")
        cmd = self.theChunk.makeContent("the words & text of this Chunk")
        self.theChunk.append(cmd)
        self.theChunk.setUserIDRefs("index terms")
        
    def test_append_output_chunk_to_web_should_work(self) -> None:
        web = MockWeb()
        self.theChunk.webAdd(web)
        self.assertEqual(web.addOutput.mock_calls, [call(self.theChunk)])

    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.theChunk.weave(web, wvr)
        self.assertEqual(wvr.mock_calls, [
                call.fileBegin(self.theChunk),
                call.quote('the words & text of this Chunk'),
                call.codeBlock('quoted'),
                call.fileEnd(self.theChunk)
            ]
        )
        
    def test_tangle_should_work(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        self.theChunk.tangle(web, tnglr)
        self.assertEqual(tnglr.mock_calls, [
                call.codeBegin(self.theChunk),
                call.codeBlock('the words & text of this Chunk'),
                call.codeEnd(self.theChunk)
            ]
        )
@}

The ``NamedDocumentChunk`` is a little-used feature.

    **TODO** Test ``NamedDocumentChunk``.

@d Unit Test of NamedDocumentChunk subclass... @{# TODO Test This @}

Command Tests
---------------

@d Unit Test of Command class hierarchy... @{ 
@<Unit Test of Command superclass@>
@<Unit Test of TextCommand class to contain a document text block@>
@<Unit Test of CodeCommand class to contain a program source code block@>
@<Unit Test of XrefCommand superclass for all cross-reference commands@>
@<Unit Test of FileXrefCommand class for an output file cross-reference@>
@<Unit Test of MacroXrefCommand class for a named chunk cross-reference@>
@<Unit Test of UserIdXrefCommand class for a user identifier cross-reference@>
@<Unit Test of ReferenceCommand class for chunk references@>
@}

This Command superclass is essentially an inteface definition, it
has no real testable features.

@d Unit Test of Command superclass... @{# No Tests@}

A TextCommand object must be constructed, interrogated and emitted.

@d Unit Test of TextCommand class... @{ 
class TestTextCommand(unittest.TestCase):
    def setUp(self) -> None:
        self.cmd = pyweb.TextCommand("Some text & words in the document\n    ", 314)
        self.cmd2 = pyweb.TextCommand("No Indent\n", 314)
    def test_methods_should_work(self) -> None:
        self.assertTrue(self.cmd.startswith("Some"))
        self.assertFalse(self.cmd.startswith("text"))
        pat1 = re.compile(r"\Wthe\W")
        self.assertTrue(self.cmd.searchForRE(pat1) is not None)
        pat2 = re.compile(r"\Wnothing\W")
        self.assertTrue(self.cmd.searchForRE(pat2) is None)
        self.assertEqual(4, self.cmd.indent())
        self.assertEqual(0, self.cmd2.indent())
        
    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.cmd.weave(web, wvr)
        self.assertEqual(wvr.write.mock_calls, [call('Some text & words in the document\n    ')])
        
    def test_tangle_should_work(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        self.cmd.tangle(web, tnglr)
        self.assertEqual(tnglr.write.mock_calls, [call('Some text & words in the document\n    ')])
@}

A CodeCommand object is a TextCommand with different processing for being emitted.

@d Unit Test of CodeCommand class... @{
class TestCodeCommand(unittest.TestCase):
    def setUp(self) -> None:
        self.cmd = pyweb.CodeCommand("Some text & words in the document\n    ", 314)
        
    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.cmd.weave(web, wvr)
        self.assertEqual(wvr.codeBlock.mock_calls, [call('quoted')])
        
    def test_tangle_should_work(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        self.cmd.tangle(web, tnglr)
        self.assertEqual(tnglr.codeBlock.mock_calls, [call('Some text & words in the document\n    ')])
@}

The XrefCommand class is largely abstract.

@d Unit Test of XrefCommand superclass... @{# No Tests @}

The FileXrefCommand command is expanded by a weaver to a list of ``@@o``
locations.

@d Unit Test of FileXrefCommand class... @{ 
class TestFileXRefCommand(unittest.TestCase):
    def setUp(self) -> None:
        self.cmd = pyweb.FileXrefCommand(314)
        
    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.cmd.weave(web, wvr)
        self.assertEqual(wvr.mock_calls, [call.xrefHead(), call.xrefLine('file', [1, 2, 3]), call.xrefFoot()])
        
    def test_tangle_should_fail(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        try:
            self.cmd.tangle(web, tnglr)
            self.fail()
        except pyweb.Error:
            pass
@}

The MacroXrefCommand command is expanded by a weaver to a list of all ``@@d``
locations.

@d Unit Test of MacroXrefCommand class... @{
class TestMacroXRefCommand(unittest.TestCase):
    def setUp(self) -> None:
        self.cmd = pyweb.MacroXrefCommand(314)
        
    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.cmd.weave(web, wvr)
        self.assertEqual(wvr.mock_calls, [call.xrefHead(), call.xrefLine('chunk', [4, 5, 6]), call.xrefFoot()])

    def test_tangle_should_fail(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        try:
            self.cmd.tangle(web, tnglr)
            self.fail()
        except pyweb.Error:
            pass
@}

The UserIdXrefCommand command is expanded by a weaver to a list of all ``@@|``
names.

@d Unit Test of UserIdXrefCommand class... @{
class TestUserIdXrefCommand(unittest.TestCase):
    def setUp(self) -> None:
        self.cmd = pyweb.UserIdXrefCommand(314)
        
    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.cmd.weave(web, wvr)
        self.assertEqual(wvr.mock_calls, [call.xrefHead(), call.xrefDefLine('name', 7, [8, 9, 10]), call.xrefFoot()])
        
    def test_tangle_should_fail(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        try:
            self.cmd.tangle(web, tnglr)
            self.fail()
        except pyweb.Error:
            pass
@}

Reference commands require a context when tangling.
The context helps provide the required indentation.
They can't be simply tangled.

@d Unit Test of ReferenceCommand class... @{ 
class TestReferenceCommand(unittest.TestCase):
    def setUp(self) -> None:
        self.chunk = MockChunk("Owning Chunk", 123, 456)
        self.cmd = pyweb.ReferenceCommand("Some Name", 314)
        self.cmd.chunk = self.chunk
        self.chunk.commands.append(self.cmd)
        self.chunk.previous_command = pyweb.TextCommand("", self.chunk.commands[0].lineNumber)
        
    def test_weave_should_work(self) -> None:
        wvr = MockWeaver()
        web = MockWeb()
        self.cmd.weave(web, wvr)
        self.assertEqual(wvr.write.mock_calls, [call('Some Name')])

    def test_tangle_should_work(self) -> None:
        tnglr = MockTangler()
        web = MockWeb()
        web.add(self.chunk)
        self.cmd.tangle(web, tnglr)
        self.assertEqual(tnglr.write.mock_calls, [call('Some Name')])

@}

Reference Tests
----------------

The Reference class implements one of two search strategies for 
cross-references.  Either simple (or "immediate") or transitive.

The superclass is little more than an interface definition,
it's completely abstract.  The two subclasses differ in 
a single method.


@d Unit Test of Reference class hierarchy... @{ 
class TestReference(unittest.TestCase):
    def setUp(self) -> None:
        self.web = MockWeb()
        self.main = MockChunk("Main", 1, 11)
        self.parent = MockChunk("Parent", 2, 22)
        self.parent.referencedBy = [ self.main ]
        self.chunk = MockChunk("Sub", 3, 33)
        self.chunk.referencedBy = [ self.parent ]
    def test_simple_should_find_one(self) -> None:
        self.reference = pyweb.SimpleReference()
        theList = self.reference.chunkReferencedBy(self.chunk)
        self.assertEqual(1, len(theList))
        self.assertEqual(self.parent, theList[0])
    def test_transitive_should_find_all(self) -> None:
        self.reference = pyweb.TransitiveReference()
        theList = self.reference.chunkReferencedBy(self.chunk)
        self.assertEqual(2, len(theList))
        self.assertEqual(self.parent, theList[0])
        self.assertEqual(self.main, theList[1])
@}

Web Tests
-----------

This is more difficult to create mocks for.

@d Unit Test of Web class... 
@{ 
class TestWebConstruction(unittest.TestCase):
    def setUp(self) -> None:
        self.web = pyweb.Web()
    @<Unit Test Web class construction methods@>
    
class TestWebProcessing(unittest.TestCase):
    def setUp(self) -> None:
        self.web = pyweb.Web()
        self.web.web_path = Path("TestWebProcessing.w")
        self.chunk = pyweb.Chunk()
        self.chunk.appendText("some text")
        self.chunk.webAdd(self.web)
        self.out = pyweb.OutputChunk("A File")
        self.out.appendText("some code")
        nm = self.web.addDefName("A Chunk")
        self.out.append(pyweb.ReferenceCommand(nm))
        self.out.webAdd(self.web)
        self.named = pyweb.NamedChunk("A Chunk...")
        self.named.appendText("some user2a code")
        self.named.setUserIDRefs("user1")
        nm = self.web.addDefName("Another Chunk")
        self.named.append(pyweb.ReferenceCommand(nm))
        self.named.webAdd(self.web)
        self.named2 = pyweb.NamedChunk("Another Chunk...")
        self.named2.appendText("some user1 code")
        self.named2.setUserIDRefs("user2a user2b")
        self.named2.webAdd(self.web)
    @<Unit Test Web class name resolution methods@>
    @<Unit Test Web class chunk cross-reference@>
    @<Unit Test Web class tangle@>
    @<Unit Test Web class weave@>
@}

@d Unit Test Web class construction... 
@{
def test_names_definition_should_resolve(self) -> None:
    name1 = self.web.addDefName("A Chunk...")
    self.assertTrue(name1 is None)
    self.assertEqual(0, len(self.web.named))
    name2 = self.web.addDefName("A Chunk Of Code")
    self.assertEqual("A Chunk Of Code", name2)
    self.assertEqual(1, len(self.web.named))
    name3 = self.web.addDefName("A Chunk...")
    self.assertEqual("A Chunk Of Code", name3)
    self.assertEqual(1, len(self.web.named))
    
def test_chunks_should_add_and_index(self) -> None:
    chunk = pyweb.Chunk()
    chunk.appendText("some text")
    chunk.webAdd(self.web)
    self.assertEqual(1, len(self.web.chunkSeq))
    self.assertEqual(0, len(self.web.named))
    self.assertEqual(0, len(self.web.output))
    named = pyweb.NamedChunk("A Chunk")
    named.appendText("some code")
    named.webAdd(self.web)
    self.assertEqual(2, len(self.web.chunkSeq))
    self.assertEqual(1, len(self.web.named))
    self.assertEqual(0, len(self.web.output))
    out = pyweb.OutputChunk("A File")
    out.appendText("some code")
    out.webAdd(self.web)
    self.assertEqual(3, len(self.web.chunkSeq))
    self.assertEqual(1, len(self.web.named))
    self.assertEqual(1, len(self.web.output))
@}

@d Unit Test Web class name resolution... 
@{ 
def test_name_queries_should_resolve(self) -> None:
    self.assertEqual("A Chunk", self.web.fullNameFor("A C..."))    
    self.assertEqual("A Chunk", self.web.fullNameFor("A Chunk"))    
    self.assertNotEqual("A Chunk", self.web.fullNameFor("A File"))
    self.assertTrue(self.named is self.web.getchunk("A C...")[0])
    self.assertTrue(self.named is self.web.getchunk("A Chunk")[0])
    try:
        self.assertTrue(None is not self.web.getchunk("A File"))
        self.fail()
    except pyweb.Error as e:
        self.assertTrue(e.args[0].startswith("Cannot resolve 'A File'"))  
@}

@d Unit Test Web class chunk cross-reference @{ 
def test_valid_web_should_createUsedBy(self) -> None:
    self.web.createUsedBy()
    # If it raises an exception, the web structure is damaged
    
def test_valid_web_should_createFileXref(self) -> None:
    file_xref = self.web.fileXref()
    self.assertEqual(1, len(file_xref))
    self.assertTrue("A File" in file_xref) 
    self.assertTrue(1, len(file_xref["A File"]))
    
def test_valid_web_should_createChunkXref(self) -> None:
    chunk_xref = self.web.chunkXref()
    self.assertEqual(2, len(chunk_xref))
    self.assertTrue("A Chunk" in chunk_xref)
    self.assertEqual(1, len(chunk_xref["A Chunk"]))
    self.assertTrue("Another Chunk" in chunk_xref)
    self.assertEqual(1, len(chunk_xref["Another Chunk"]))
    self.assertFalse("Not A Real Chunk" in chunk_xref)
    
def test_valid_web_should_create_userNamesXref(self) -> None:
    user_xref = self.web.userNamesXref() 
    self.assertEqual(3, len(user_xref))
    self.assertTrue("user1" in user_xref)
    defn, reflist = user_xref["user1"]
    self.assertEqual(1, len(reflist), "did not find user1")
    self.assertTrue("user2a" in user_xref)
    defn, reflist = user_xref["user2a"]
    self.assertEqual(1, len(reflist), "did not find user2a")
    self.assertTrue("user2b" in user_xref)
    defn, reflist = user_xref["user2b"]
    self.assertEqual(0, len(reflist))
    self.assertFalse("Not A User Symbol" in user_xref)
@}

@d Unit Test Web class tangle @{ 
def test_valid_web_should_tangle(self) -> None:
    tangler = MockTangler()
    self.web.tangle(tangler)
    self.assertEqual(tangler.codeBlock.mock_calls, [
            call('some code'),
            call('some user2a code'),
            call('some user1 code'),
        ]
    )
@}

@d Unit Test Web class weave @{ 
def test_valid_web_should_weave(self) -> None:
    weaver = MockWeaver()
    self.web.weave(weaver)
    self.assertEqual(weaver.write.mock_calls, [
            call('some text'),
        ]
    )
    self.assertEqual(weaver.quote.mock_calls, [
            call('some code'),
            call('some user2a code'),
            call('some user1 code'),
        ]
    )
@}


WebReader Tests
----------------

Generally, this is tested separately through the functional tests.
Those tests each present source files to be processed by the
WebReader.

We should test this through some clever mocks that produce the
proper sequence of tokens to parse the various kinds of Commands.

@d Unit Test of WebReader... @{
# Tested via functional tests
@}

Some lower-level units: specifically the tokenizer and the option parser.

@d Unit Test of WebReader... @{
class TestTokenizer(unittest.TestCase):
    def test_should_split_tokens(self) -> None:
        input = io.StringIO("@@@@ word @@{ @@[ @@< @@>\n@@] @@} @@i @@| @@m @@f @@u\n")
        self.tokenizer = pyweb.Tokenizer(input)
        tokens = list(self.tokenizer)
        self.assertEqual(24, len(tokens))
        self.assertEqual( ['@@@@', ' word ', '@@{', ' ', '@@[', ' ', '@@<', ' ', 
        '@@>', '\n', '@@]', ' ', '@@}', ' ', '@@i', ' ', '@@|', ' ', '@@m', ' ', 
        '@@f', ' ', '@@u', '\n'], tokens )
        self.assertEqual(2, self.tokenizer.lineNumber)
@}

@d Unit Test of WebReader... @{
class TestOptionParser_OutputChunk(unittest.TestCase):
    def setUp(self) -> None:
        self.option_parser = pyweb.OptionParser(        
            pyweb.OptionDef("-start", nargs=1, default=None),
            pyweb.OptionDef("-end", nargs=1, default=""),
            pyweb.OptionDef("argument", nargs='*'),
        )
    def test_with_options_should_parse(self) -> None:
        text1 = " -start /* -end */ something.css "
        options1 = self.option_parser.parse(text1)
        self.assertEqual({'-end': ['*/'], '-start': ['/*'], 'argument': ['something.css']}, options1)
    def test_without_options_should_parse(self) -> None:
        text2 = " something.py "
        options2 = self.option_parser.parse(text2)
        self.assertEqual({'argument': ['something.py']}, options2)
        
class TestOptionParser_NamedChunk(unittest.TestCase):
    def setUp(self) -> None:
        self.option_parser = pyweb.OptionParser(        pyweb.OptionDef( "-indent", nargs=0),
        pyweb.OptionDef("-noindent", nargs=0),
        pyweb.OptionDef("argument", nargs='*'),
        )
    def test_with_options_should_parse(self) -> None:
        text1 = " -indent the name of test1 chunk... "
        options1 = self.option_parser.parse(text1)
        self.assertEqual({'-indent': [], 'argument': ['the', 'name', 'of', 'test1', 'chunk...']}, options1)
    def test_without_options_should_parse(self) -> None:
        text2 = " the name of test2 chunk... "
        options2 = self.option_parser.parse(text2)
        self.assertEqual({'argument': ['the', 'name', 'of', 'test2', 'chunk...']}, options2)
@}


Action Tests
-------------

Each class is tested separately.  Sequence of some mocks, 
load, tangle, weave.  

@d Unit Test of Action class hierarchy... @{ 
@<Unit test of Action Sequence class@>
@<Unit test of LoadAction class@>
@<Unit test of TangleAction class@>
@<Unit test of WeaverAction class@>
@}

**TODO:** Replace with Mock

@d Unit test of Action Sequence class... @{
class TestActionSequence(unittest.TestCase):
    def setUp(self) -> None:
        self.web = MockWeb()
        self.a1 = MagicMock(name="Action1")
        self.a2 = MagicMock(name="Action2")
        self.action = pyweb.ActionSequence("TwoSteps", [self.a1, self.a2])
        self.action.web = self.web
        self.action.options = argparse.Namespace()
    def test_should_execute_both(self) -> None:
        self.action()
        self.assertEqual(self.a1.call_count, 1)
        self.assertEqual(self.a2.call_count, 1)
@}

@d Unit test of WeaverAction class... @{ 
class TestWeaveAction(unittest.TestCase):
    def setUp(self) -> None:
        self.web = MockWeb()
        self.action = pyweb.WeaveAction()
        self.weaver = MockWeaver()
        self.action.web = self.web
        self.action.options = argparse.Namespace( 
            theWeaver=self.weaver,
            reference_style=pyweb.SimpleReference(),
            output=Path.cwd(),
        )
    def test_should_execute_weaving(self) -> None:
        self.action()
        self.assertEqual(self.web.weave.mock_calls, [call(self.weaver)])
@}

@d Unit test of TangleAction class... @{ 
class TestTangleAction(unittest.TestCase):
    def setUp(self) -> None:
        self.web = MockWeb()
        self.action = pyweb.TangleAction()
        self.tangler = MockTangler()
        self.action.web = self.web
        self.action.options = argparse.Namespace( 
            theTangler = self.tangler,
            tangler_line_numbers = False, 
            output=Path.cwd()
        )
    def test_should_execute_tangling(self) -> None:
        self.action()
        self.assertEqual(self.web.tangle.mock_calls, [call(self.tangler)])
@}

The mocked ``WebReader`` must provide an ``errors`` property to the ``LoadAction`` instance.

@d Unit test of LoadAction class... @{ 
class TestLoadAction(unittest.TestCase):
    def setUp(self) -> None:
        self.web = MockWeb()
        self.action = pyweb.LoadAction()
        self.webReader = Mock(
            name="WebReader",
            errors=0,
        )
        self.action.web = self.web
        self.source_path = Path("TestLoadAction.w")
        self.action.options = argparse.Namespace( 
            webReader = self.webReader, 
            source_path=self.source_path,
            command="@@",
            permitList = [], 
            output=Path.cwd(),
        )
        Path("TestLoadAction.w").write_text("")
    def tearDown(self) -> None:
        try:
            Path("TestLoadAction.w").unlink()
        except IOError:
            pass
    def test_should_execute_loading(self) -> None:
        self.action()
        # Old: self.assertEqual(1, self.webReader.count)
        print(self.webReader.load.mock_calls)
        self.assertEqual(self.webReader.load.mock_calls, [call(self.web, self.source_path)])
        self.webReader.web.assert_not_called()  # Deprecated
        self.webReader.source.assert_not_called()  # Deprecated
@}

Application Tests
------------------

As with testing WebReader, this requires extensive mocking.
It's easier to simply run the various use cases.

**TODO:** Test Application class

@d Unit Test of Application... @{# TODO Test Application class @}

Overheads and Main Script
--------------------------

The boilerplate code for unit testing is the following.

@d Unit Test overheads...
@{"""Unit tests."""
import argparse
import io
import logging
import os
from pathlib import Path
import re
import string
import sys
import textwrap
import time
from typing import Any, TextIO
import unittest
from unittest.mock import Mock, call, MagicMock, sentinel
import warnings

import pyweb
@}

One more overhead is a function we can inject into selected subclasses
of ``unittest.TestCase``. This is monkeypatch feature that seems useful.

@d Unit Test overheads...
@{
def rstrip_lines(source: str) -> list[str]:
    return list(l.rstrip() for l in source.splitlines())    
@}

@d Unit Test main...
@{
if __name__ == "__main__":
    logging.basicConfig(stream=sys.stdout, level=logging.WARN)
    unittest.main()
@}

We run the default ``unittest.main()`` to execute the entire suite of tests.
