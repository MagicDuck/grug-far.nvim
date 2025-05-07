local parseResults = require('grug-far.engine.astgrep.parseResults')
local MiniTest = require('mini.test')
local expect = MiniTest.expect

describe('splitMatchLines', function()
  it('splits when everything on one line', function()
    local lead = '<pre>'
    local match = '<match>'
    local trail = '<post>'
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '')
    expect.equality(matchLines, '<pre><match><post>')
    expect.equality(trailingLines, '')
  end)
  it('splits when multiline match with no trailing', function()
    local lead = '<pre>'
    local match = '<match1>\n<match2>\n<match3>'
    local trail = ''
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '')
    expect.equality(matchLines, '<pre><match1>\n<match2>\n<match3>')
    expect.equality(trailingLines, '')
  end)
  it('splits when multiline match with no leading', function()
    local lead = ''
    local match = '<match1>\n<match2>\n<match3>'
    local trail = '<post>'
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '')
    expect.equality(matchLines, '<match1>\n<match2>\n<match3><post>')
    expect.equality(trailingLines, '')
  end)
  it('splits when no leading or trailing', function()
    local lead = ''
    local match = '<match>'
    local trail = ''
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '')
    expect.equality(matchLines, '<match>')
    expect.equality(trailingLines, '')
  end)
  it('splits when match has multiple lines', function()
    local lead = '<pre>'
    local match = '<match1>\n<match2>'
    local trail = '<post>'
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '')
    expect.equality(matchLines, '<pre><match1>\n<match2><post>')
    expect.equality(trailingLines, '')
  end)
  it('splits when match has multiple leading lines', function()
    local lead = '<pre1>\n<pre2>\n<pre3>'
    local match = '<match1>\n<match2>'
    local trail = '<post>'
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '<pre1>\n<pre2>')
    expect.equality(matchLines, '<pre3><match1>\n<match2><post>')
    expect.equality(trailingLines, '')
  end)
  it('splits when match has multiple trailing lines', function()
    local lead = '<pre>'
    local match = '<match1>\n<match2>'
    local trail = '<post1>\n<post2>\n<post3>'
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '')
    expect.equality(matchLines, '<pre><match1>\n<match2><post1>')
    expect.equality(trailingLines, '<post2>\n<post3>')
  end)
  it('splits when match has multiple leading and trailing lines', function()
    local lead = '<pre1>\n<pre2>\n<pre3>'
    local match = '<match1>\n<match2>'
    local trail = '<post1>\n<post2>\n<post3>'
    local leadingLines, matchLines, trailingLines =
      parseResults.splitMatchLines(lead .. match .. trail, #lead, #trail)
    expect.equality(leadingLines, '<pre1>\n<pre2>')
    expect.equality(matchLines, '<pre3><match1>\n<match2><post1>')
    expect.equality(trailingLines, '<post2>\n<post3>')
  end)
end)
