#
# Layout for viewing an individual message
#

_html do
  _title 'ASF Secretary Workbench'

  _frameset cols: '20%, 70%' do
    _frame src: '_index_'
    _frame name: 'content', src: '_body_'
  end
end
