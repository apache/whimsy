#!/usr/bin/env ruby

#         DRAFT DRAFT DRAFT
#         DRAFT DRAFT DRAFT
#         DRAFT DRAFT DRAFT
#         DRAFT DRAFT DRAFT
#         DRAFT DRAFT DRAFT

#
# ICLA PDF parsing support
#
# Try to extract user text from ICLA PDFs.

# The Gem is not 100% accurate in creating a text version of the page.
# Also it's tricky to extract the text accurately.

# So we try other methods first:
# - if there is a form, return its fields
# - if there are FreeText Annotations, return them in page order
# - use show_text_with_positioning as that seems to be used for PDF updates
# - where the PDF only uses show_text, the Gem is better at combining the data, so use page.txt

require 'pdf-reader'

# TODO perhaps always extract all the data types then choose the best
# Should turn hash values into arrays?
module ICLAParser
  # Process page to extract text with positioning elements
  # These are often used instead of providing form fields
  class Receiver
    SKIP = [
      # Short elements that are not user data
      'Individual Contributor',
      'License Agreement',
      '("Agreement") V2.0',
      "as \"Not a Contribution.\"",
      "inaccurate in any respect.",
      "for your records.",
      "1. Definitions.",
      "Contributions and such derivative works.",
      "litigation is filed.",
      "Contributions."
    ]

    def initialize(fontdict)
      @texts = [] # show_text_with_positioning
      @lines = [] # show_text
      @tfs = nil # text font and size
      @fontdict = fontdict
    end

    # Some PDFs use show_text() multiple times in a line
    def begin_text_object
      @textobj = []
    end

    def end_text_object
      @lines << @textobj.join
    end

    def set_text_font_and_size(*args)
      @tfs = args
    end

    def show_text(string)
      font = @fontdict[@tfs.first]
      utf8 = string_to_utf8(string, font)
      @textobj << utf8
    end

    def show_text_with_positioning(*args)
      font = @fontdict[@tfs.first]
      # args are Strings (in the current font encoding) interspersed with integer spacing adjustments; only want the strings
      # We assume the positioning does not overlay characters so can be ignored
      chars = []
      args.flatten.each do |arg|
        if arg.is_a?(String)
          char = string_to_utf8(arg, font)
          chars << char
        end
      end
      val = chars.join.strip
      len = val.length
      # some PDFs have the individual text in this format so skip long lines which are unlikely to be user data
      # Could perhaps have full list of expected text lines instead.
      unless len == 0 or len > 50 or SKIP.include? val
        @texts << val
      end
    end

    def get_text
      @texts
    end

    def get_lines
      @lines
    end

    def string_to_utf8(string, font)
      chars = []
      glyphs = font.unpack(string)
      glyphs.each do |glyph_code|
        char = font.to_utf8(glyph_code)
        # One pdf (yev) has spurious \t\r<sp>?<nbsp> translated from 36 => [9, 13, 32, 194, 160]
        if glyph_code == 36 and char =~ /^\t\r /
          char = ' '
        end
        chars << char
      end
      chars.join
    end

  end

  # Standard form field names for other code to use
  NAME2FIELD = {
    'fullname' => :FullName,
    'publicname' => :PublicName,
    'familyfirst' => :FamilyFirst,
    'mailingaddress' => :MailingAddress,
    'mailingaddress2' => :MailingAddress2,
    'postaladdress' => :MailingAddress,
    'postaladdress2' => :MailingAddress2,
    'country' => :Country,
    'formattedfield1' => :Country, # fix up bad form name
    'telephone' => :Telephone,
    'e-mail' => :EMail,
    'preferredapacheid(s)' => :ApacheID,
    'notifyproject' => :Project,
    'date' => :Date,
    'signature' => :Signature,
  }

  # canonicalise the names found in the PDF
  def self.canon_field_name(pdfname)
    NAME2FIELD[pdfname.gsub(' ', '').downcase] || pdfname
  end

  def self.encode(val)
    if val.bytes[0..1] == [254, 255]
      val = val.encode('utf-8', 'utf-16').strip
    else
      begin
        val = val.encode('utf-8').strip
      rescue Encoding::UndefinedConversionError
        val = val.encode('utf-8', 'iso-8859-1').strip
      end
    end
    val.gsub("\x7F", '') # Not sure where these originate
  end

  # parse the PDF
  def self.parse(path)
    data = {}
    metadata = {}
    data[:_meta] = metadata
    metadata[:dataSource] = {} # have we found anything
    freetext = {} # gather the free text details
    debug = {}
    begin
      reader = PDF::Reader.new(path)
      %w(pdf_version info metadata page_count).each do |i|
        metadata[i] = reader.public_send(i)
      end
      reader.objects.each do |_k, v|
        type = v[:Type] rescue nil
        subtype = v[:Subtype] rescue nil

        if type == :Annot
          if subtype == :FreeText # These are not directly associated with forms
            rect = v[:Rect]
            # rect can be a reference. If so, it seems there may be multiple copies with different IDs but same Rect coords and contents
            if rect.is_a?(PDF::Reader::Reference)
              rect = reader.objects.deref(rect)
            end
            if rect.is_a?(Array)
              contents = v[:Contents]
              if contents and contents.length > 0 and contents != "\x14" # ignore "\x14" == ASCII DC4
                # Entries may be duplicated, so use a hash to store them
                id = rect.inspect + contents # if the rect and contents match, then they overwrite each other
                freetext[id] = {Contents: contents.strip, x: rect[0], y: rect[1]}
                metadata[:dataSource]['FreeText'] = true
              end
            else
              puts "warn: #{contents} Rect is #{rect.class} in #{path}"
            end
          else
            key = v[:T]
            if key
              val = v[:V].to_s # might be a symbol
              # This is a hack; should really find the font def and use that
              if val
                debug[key] = v.inspect
                val = encode(val)
                if val.length > 0
                  ckey = canon_field_name(key)
                  if ckey == :FamilyFirst # convert the value to true/false
                    # PDFs seem to use Yes and Off; also allow for On
                    data[ckey] = %w(Yes On).include? val # default to false
                  else
                    data[ckey] = val
                  end
                end
                metadata[:dataSource]['Form'] = true
              end
            end
          end
        elsif subtype == :Widget
          key = v[:T]
          val = v[:V].to_s # might be a symbol
          if val
            debug[key] = v.inspect
            if val.length > 0
              data[canon_field_name(key)] = val
            end
          end
        else
          next if [:Catalog, :Font, :FontDescriptor].include? type
          # p [k,type,subtype,v]
        end
      end # objects
      if freetext.size > 0
        data[:text] = []
        # Sort by Y descending (down the page) and X ascending (across)
        # split into separate chunks if the difference in Y is more than a few points
        how_close = 3
        freetext.values. # no need for ids any more
          sort_by {|e| -e[:y] }. # sort by Y desc
          slice_when {|i, j| (i[:y] - j[:y]) > how_close}. # gather nearby Y values in case there are multiple entries on a line
          each do |k|
            data[:text] << k.
            sort_by {|l| l[:x]}. # sort by X ascending
            map {|v| v[:Contents]}.join(", ")
          end
      end
      if metadata[:dataSource].size == 0 or ((data[:text].size rescue 0) <= 1 and data.size < 3) # No annotations found or not useful
        page1 = nil # cache for page 1
        fontdict = {}
        # Try looking for text sections instead
        receiver = Receiver.new(fontdict)
        reader.pages.each do |page|
          # extract the fonts (needed for conversion to utf-8)
          page.fonts.each do |label, font|
            fontdict[label] ||= PDF::Reader::Font.new(page.objects, page.objects.deref(font))
          end
          page.walk(receiver)
          page1 ||= page.text
        end
        # pickup up the collected strings
        text = receiver.get_text()
#        p text
        lines = receiver.get_lines() # do we still need these?
        debug[:lines] = lines
        if text.length > 3
          metadata[:dataSource]['Text'] = true
          data[:text] = text
        else
          page1.each_line.slice_before(/^\s+Full name:/).each_with_index do |lump, i|
            if i == 1 # starts with Full name
              metadata[:dataSource]['Page'] = true
              # drop the postamble
              form = lump.slice_before(/^\S/).first
              # split into headers
              form.slice_before(/^\s+.+:/).each do |lines|
                # trim leading and trailing blanks and underscores and drop blank lines
                line = lines.map {|l| l.sub(/^[ _]+/, '').sub(/[ _]+$/, '')}.select {|l| l.length > 0}.join(',')
                case line
                  when /^\s*(?:\(optional\) )?(.+):\s+(.*)/
                    data[canon_field_name($1)] = $2 unless $2 == ',' or $2 == '' # empty line
                  else
                    data[:unmatched] ||= []
                    data[:unmatched] << line
                end
              end
            end
          end
        end
      end
    rescue StandardError => e
      data[:error] = "Error processing #{path} => #{e.inspect}\n#{e.backtrace.join("\n")}"
    end
#    data[:debug] = debug
    # TODO attempt to classify data[:text] items?
    data
  end
end

if __FILE__ == $0
  require 'pp'
  pp ICLAParser.parse(ARGV.first)
end
