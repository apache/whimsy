#!/usr/bin/env ruby
$LOAD_PATH.unshift File.realpath(File.expand_path('../../../lib', __FILE__))
require 'csv'
require 'json'
require 'whimsy/asf'
require 'wunderbar'
require 'wunderbar/bootstrap'

PAGETITLE = 'Whimsy Testing JSON File Editor'

_html do
  _body? do
    _head do
      # Style lines - any needed?
      _script src: "assets/jsoneditor.min.js"
      _script %{
        // Set the default CSS theme and icon library globally
        JSONEditor.defaults.theme = 'bootstrap3';
        console.log('Theme init DEBUG')
      }
    end
    _whimsy_header PAGETITLE


    _p do 
      _ 'Test application for manipulating JSON files locally; uses '
      _a 'https://github.com/jdorn/json-editor', href: 'https://github.com/jdorn/json-editor'
      _ ' under MIT license (TODO: if merged, update NOTICE).'
    end
    _div.row do
      _div.col_md_12 do
        _button.btn.btn_sm.btn_default.submit! 'Submit (console.log)'
        _button.btn.btn_sm.btn_info.restore! 'Restore to Default'
        _span.label.valid_indicator! 'X'
      end
    end
    _div.row do
      _div.col_md_12 do
        _div.medium_12.columns.editor_holder!
      end
    end

    _div.row do
      _p "Editor in above row; init script follows (check logs)."
    end
      
    _script %{
      // This is the starting value for the editor
      // We will use this to seed the initial editor 
      // and to provide a "Restore to Default" button.
      var starting_value = {
        "committee-info.json": {
          "period": "d",
          "maintainer": "generator",
          "model": "ASF::Committee",
          "generator": "tools/public_committee_info.rb",
          "usedby": [
            "https://projects.apache.org",
            "https://whimsy.apache.org/"
          ],
          "sources": [
            "private/committers/board/committee-info.txt",
            "ASF::LDAP"
          ]
        }
      };
      
      // Initialize the editor
      var editor = new JSONEditor(document.getElementById('editor_holder'),{
        // Enable fetching schemas via ajax
        ajax: true,
        
        // The schema for the editor
        schema: {
          $ref: "dataflow-schema.json",
          format: "grid"
        },
        
        // Seed the form with a starting value
        startval: starting_value
      });
      
      // Hook up the submit button to log to the console
      document.getElementById('submit').addEventListener('click',function() {
        // Get the value from the editor
        console.log('DEBUG1: ' + editor.getValue());
      });
      
      // Hook up the Restore to Default button
      document.getElementById('restore').addEventListener('click',function() {
        editor.setValue(starting_value);
      });
      
      // Hook up the validation indicator to update its 
      // status whenever the editor changes
      editor.on('change',function() {
        // Get an array of errors from the validator
        var errors = editor.validate();
        
        var indicator = document.getElementById('valid_indicator');
        
        // Not valid
        if(errors.length) {
          indicator.className = 'label alert';
          indicator.textContent = 'not valid';
        }
        // Valid
        else {
          indicator.className = 'label success';
          indicator.textContent = 'valid';
        }
      });
    }
    
    _whimsy_footer({
      "https://whimsy.apache.org/public/" => "Whimsy public data files",
      "https://whimsy.apache.org/technology/" => "Whimsy Technology",
      "https://projects.apache.org/about/" => "projects.a.o website",
      })
  end
end
