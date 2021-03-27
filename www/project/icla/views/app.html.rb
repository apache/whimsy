#!/usr/bin/env ruby
# encoding: utf-8
require 'wunderbar/bootstrap'

_html lang: 'en', _width: '80' do
  _head_ do
    _meta name: 'viewport', content: 'width=device-width, initial-scale=1'
    _link rel: 'shortcut icon',
      href: '/favicon.ico'
    _title 'ASF ICLA demo'
    _link href: 'https://www.apache.org/css/styles.css', rel: 'stylesheet'
    _link href: "css/icla.css?#{@cssmtime}", rel: 'stylesheet'

    _.comment! 'Licensed to the Apache Software Foundation (ASF) under one ' +
      'or more contributor license agreements. See the NOTICE file ' +
      'distributed with this work for additional information regarding ' +
      'copyright ownership. The ASF licenses this file to you under the ' +
      'Apache License, Version 2.0 (the "License"); you may not ' +
      'use this file except in compliance with the License. You may obtain a ' +
      'copy of the License at . http://www.apache.org/licenses/LICENSE-2.0 . ' +
      'Unless required by applicable law or agreed to in writing, software ' +
      'distributed under the License is distributed on an "AS IS" ' +
      'BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express ' +
      'or implied. See the License for the specific language governing ' +
      'permissions and limitations under the License.'
  end

  _body_ do
    _.comment! 'Navigation'

    _header_ do
      _nav_.navbar.navbar_default.navbar_fixed_top do
        _div_.container do
          _div_.navbar_header do
            _button_.navbar_toggle type: 'button', data_toggle: 'collapse',
              data_target: '#mainnav-collapse' do
              _span.sr_only 'Toggle navigation'
              _span.icon_bar
              _span.icon_bar
              _span.icon_bar
            end

            _a.navbar_brand href: 'https://www.apache.org/foundation/board/calendar.html#' do
              _span.glyphicon.glyphicon_home
            end
          end

          _div_.collapse.navbar_collapse.mainnav_collapse! do
            _div_! style: 'line-height:20px; padding-top:5px; float:left' do
              _a 'Home', href: 'https://www.apache.org/'
              _ " » "
              _a 'Legal', href: 'https://www.apache.org/legal/'
              _ " » "
              _a 'ICLA', href: '/project/icla/'
            end

            _ul_.nav.navbar_nav.navbar_right do
              _li_.dropdown do
                _a.dropdown_toggle href: 'https://www.apache.org/foundation/board/calendar.html#',
                  data_toggle: 'dropdown' do
                  _ 'About'
                  _span.caret
                end

                _ul_.dropdown_menu role: 'menu' do
                  _li do
                    _a 'Overview', href: 'https://www.apache.org/foundation'
                  end
                  _li do
                    _a 'Members',
                      href: 'https://www.apache.org/foundation/members.html'
                  end
                  _li do
                    _a 'Process',
                      href: 'https://www.apache.org/foundation/how-it-works.html'
                  end
                  _li do
                    _a 'Sponsorship',
                      href: 'https://www.apache.org/foundation/sponsorship.html'
                  end
                  _li do
                    _a 'Glossary',
                      href: 'https://www.apache.org/foundation/glossary.html'
                  end
                  _li do
                    _a 'FAQ',
                      href: 'https://www.apache.org/foundation/preFAQ.html'
                  end
                  _li do
                    _a 'Contact',
                      href: 'https://www.apache.org/foundation/contact.html'
                  end
                end
              end

              _li do
                _a 'Projects',
                  href: 'https://www.apache.org/foundation/board/calendar.html#projects-list'
              end

              _li_.dropdown do
                _a.dropdown_toggle href: 'https://www.apache.org/foundation/board/calendar.html#',
                  data_toggle: 'dropdown' do
                  _ 'People'
                  _span.caret
                end

                _ul_.dropdown_menu role: 'menu' do
                  _li { _a 'Overview', href: 'http://people.apache.org/' }
                  _li do
                    _a 'Committers',
                      href: 'http://people.apache.org/committer-index.html'
                  end
                  _li do
                    _a 'Meritocracy',
                      href: 'https://www.apache.org/foundation/how-it-works.html#meritocracy'
                  end
                  _li do
                    _a 'Roles',
                      href: 'https://www.apache.org/foundation/how-it-works.html#roles'
                  end
                  _li { _a 'Planet Apache', href: 'http://planet.apache.org/' }
                end
              end

              _li_.dropdown do
                _a.dropdown_toggle href: 'https://www.apache.org/foundation/board/calendar.html#',
                  data_toggle: 'dropdown' do
                  _ 'Get Involved'
                  _span.caret
                end

                _ul_.dropdown_menu role: 'menu' do
                  _li do
                    _a 'Overview',
                      href: 'https://www.apache.org/foundation/getinvolved.html'
                  end
                  _li do
                    _a 'Community Development',
                      href: 'http://community.apache.org/'
                  end
                  _li { _a 'ApacheCon', href: 'http://www.apachecon.com/' }
                end
              end

              _li do
                _a 'Download', href: 'https://www.apache.org/dyn/closer.cgi'
              end

              _li_.dropdown do
                _a.dropdown_toggle href: 'https://www.apache.org/foundation/board/calendar.html#',
                  data_toggle: 'dropdown' do
                  _ 'Support Apache'
                  _span.caret
                end

                _ul_.dropdown_menu role: 'menu' do
                  _li do
                    _a 'Sponsorship',
                      href: 'https://www.apache.org/foundation/sponsorship.html'
                  end
                  _li do
                    _a 'Donations',
                      href: 'https://www.apache.org/foundation/contributing.html'
                  end
                  _li do
                    _a 'Buy Stuff',
                      href: 'https://www.apache.org/foundation/buy_stuff.html'
                  end
                  _li do
                    _a 'Thanks',
                      href: 'https://www.apache.org/foundation/thanks.html'
                  end
                end
              end
            end
          end
        end
      end
    end

    _.comment! '/ Navigation'

    _div_.container do
      _div_.row do
        _div.col_md_9.col_sm_8.col_xs_12 do
          _img src: 'https://id.apache.org/img/asf_logo_wide.png',
            alt: 'Apache Logo', style: 'max-width: 77%;'
          _img src: '/whimsy.svg',
            alt: 'Whimsy Logo', style: 'max-width: 22%'
        end

        _div_.col_md_3.col_sm_4.col_xs_12 do
          _div_.input_group style: 'margin-bottom: 5px;' do
            _input.form_control.projectSearch! type: 'text',
              placeholder: 'Search...'

            _span_.input_group_btn do
              _button.btn.btn_primary type: 'button' do
                _span.glyphicon.glyphicon_search aria_hidden: 'true'
                _span.sr_only 'Search'
              end
            end
          end

          _a.btn.btn_block.btn_default.btn_xs 'The Apache Way', role: 'button',
            href: 'https://www.apache.org/foundation/governance/'
          _a.btn.btn_block.btn_default.btn_xs 'Contribute', role: 'button',
            href: 'https://community.apache.org/contributors/'
          _a.btn.btn_block.btn_default.btn_xs 'ASF Sponsors', role: 'button',
            href: 'https://www.apache.org/foundation/thanks.html'
        end
      end
    end

    _.comment! 'Main content'

    _div_.container.main!

    _.comment! 'Footer'

    _footer_.bg_primary do
      _div_.container do
        _div_.row do
          _br
          _div.col_sm_1 ''

          _div_.col_sm_2 do
            _h5.white 'Community'

            _ul_.list_unstyled.white role: 'menu' do
              _li { _a 'Overview', href: 'http://community.apache.org/' }
              _li do
                _a 'Conferences',
                  href: 'https://www.apache.org/foundation/conferences.html'
              end
              _li do
                _a 'Summer of Code',
                  href: 'http://community.apache.org/gsoc.html'
              end
              _li do
                _a 'Getting Started',
                  href: 'http://community.apache.org/newcomers/'
              end
              _li do
                _a 'The Apache Way',
                  href: 'https://www.apache.org/foundation/how-it-works.html'
              end
              _li do
                _a 'Travel Assistance', href: 'https://www.apache.org/travel/'
              end
              _li do
                _a 'Get Involved',
                  href: 'https://www.apache.org/foundation/getinvolved.html'
              end
              _li do
                _a 'Community FAQ',
                  href: 'http://community.apache.org/newbiefaq.html'
              end
            end
          end

          _div_.col_sm_2 do
            _h5.white 'Innovation'

            _ul_.list_unstyled.white role: 'menu' do
              _li { _a 'Incubator', href: 'http://incubator.apache.org/' }
              _li { _a 'Licensing', href: 'https://www.apache.org/licenses/' }
              _li do
                _a 'Licensing FAQ',
                  href: 'https://www.apache.org/foundation/license-faq.html'
              end
              _li do
                _a 'Trademark Policy',
                  href: 'https://www.apache.org/foundation/marks/'
              end
              _li do
                _a 'Contacts', href: 'https://www.apache.org/contact.html'
              end
            end
          end

          _div_.col_sm_2 do
            _h5.white 'Tech Operations'

            _ul_.list_unstyled.white role: 'menu' do
              _li do
                _a 'Developer Information', href: 'https://www.apache.org/dev/'
              end
              _li do
                _a 'Infrastructure',
                  href: 'https://www.apache.org/dev/infrastructure.html'
              end
              _li { _a 'Security', href: 'https://www.apache.org/security/' }
              _li { _a 'Status', href: 'http://status.apache.org' }
              _li do
                _a 'Contacts',
                  href: 'https://www.apache.org/foundation/contact.html'
              end
            end
          end

          _div_.col_sm_2 do
            _h5.white 'Press'

            _ul_.list_unstyled.white role: 'menu' do
              _li { _a 'Overview', href: 'https://www.apache.org/press/' }
              _li { _a 'ASF News', href: 'https://blogs.apache.org/' }
              _li do
                _a 'Announcements',
                  href: 'https://blogs.apache.org/foundation/'
              end
              _li { _a 'Twitter Feed', href: 'https://twitter.com/TheASF' }
              _li do
                _a 'Contacts', href: 'https://www.apache.org/press/#contact'
              end
            end
          end

          _div_.col_sm_2 do
            _h5.white 'Legal'

            _ul_.list_unstyled.white role: 'menu' do
              _li { _a 'Legal Affairs', href: 'https://www.apache.org/legal/' }
              _li { _a 'Licenses', href: 'https://www.apache.org/licenses/' }
              _li do
                _a 'Trademark Policy',
                  href: 'https://www.apache.org/foundation/marks/'
              end
              _li do
                _a 'Public Records',
                  href: 'https://www.apache.org/foundation/records/'
              end
              _li do
                _a 'Export Information',
                  href: 'https://www.apache.org/licenses/exports/'
              end
              _li do
                _a 'License/Distribution FAQ',
                  href: 'https://www.apache.org/foundation/license-faq.html'
              end
              _li do
                _a 'Contacts',
                  href: 'https://www.apache.org/foundation/contact.html'
              end
            end
          end

          _div.col_sm_1 ''
        end

        _hr.col_lg_12.hr_white

        _div_.row do
          _div_.col_lg_12 do
            _p_!.text_center do
              _ "Copyright © #{Date.today.year} The Apache Software Foundation, Licensed " +
                "under the "
              _a.white 'Apache License, Version 2.0',
                href: 'http://www.apache.org/licenses/LICENSE-2.0'
              _ '.'
            end

            _p.text_center 'Apache and the Apache feather logo are ' +
              'trademarks of The Apache Software Foundation.'
          end
        end
      end
    end

    _.comment! '/ Footer'
    _script src: "app.js?#{@appmtime}"

    _.render '#main' do
      # This sets up @@data and @@view; they are used by main.js.rb
      # The variables are set up by ../main.rb for each URL
      _Main data: {
                    allData: @allData,
                    token: @token,
                    progress: @progress,
                    user: @user,
                    member: @member,
                    debug: @debug
                  },
            view: @view
    end
  end
end
