// API references:
// - https://mupdf.readthedocs.io/en/latest/tools/mutool-run.html
// - https://mupdf.readthedocs.io/en/latest/reference/javascript/types/PDFDocument.html

if (scriptArgs.length != 2) {
    print("Usage: mutool run", scriptPath, "input.pdf", "output.pdf")
    quit(1)
}

print("==> Processing:", scriptArgs[0])
var doc = Document.openDocument(scriptArgs[0])
var pages = doc.countPages()
var blanks = 4 - pages % 4
if (blanks < 4) {
    // Copy the geometry of the last page to subsequent blank pages
    var blankPage = doc.addPage(doc.loadPage(pages - 1).getBounds(), 0, null, "")
    for (var i = 0; i < blanks; i++) {
        doc.insertPage(-1, blankPage)
    }
    print(" -> Pages:", pages, "(+" + blanks + " deliberately left blank)")
    pages += blanks
} else {
    print(" -> Pages:", pages)
}

var sheets = pages / 4
var offset = pages / 2
var order = []
for (var i = 0; i < sheets; i++) {
    order.push(i * 2)
    order.push(offset + i * 2)
    order.push(offset + i * 2 + 1)
    order.push(i * 2 + 1)
}
doc.rearrangePages(order)
for (var i in order) {
    order[i]++
}
print(" -> Order:", order)

print("==> Writing:", scriptArgs[1])
doc.save(scriptArgs[1])
print("==> Booklet ready to print with settings:\n -> Double-sided: On (Short Edge)\n -> Layout: 2 pages per sheet")
