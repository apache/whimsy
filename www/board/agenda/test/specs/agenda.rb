class AgendaPage
  def initialize(page)
    browser.get(page)
  end

  def title(n)
    return element(by.repeater('item in agenda').row(n).
      column('{{ item.title }}')).getText()
  end

  def class(n)
    return element(by.repeater('item in agenda').row(n)).getAttribute('class')
  end

  def nav(n)
    return element(by.repeater('item in toc').row(n)).getOuterHtml()
  end
end

describe 'agenda' do
  agenda = AgendaPage.new('/2014-03-19/')

  it 'should include cordova' do
    agenda.title(35).must_equal 'Cordova'
    agenda.class(35).must_equal 'missing'
  end

  it 'nav should include special orders' do
    agenda.nav(5).must_include 'Establish-Tajo'
  end
end
