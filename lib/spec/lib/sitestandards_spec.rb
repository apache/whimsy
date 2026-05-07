# encoding: utf-8
# frozen_string_literal: true

#  Licensed to the Apache Software Foundation (ASF) under one or more
#  contributor license agreements.  See the NOTICE file distributed with
#  this work for additional information regarding copyright ownership.
#  The ASF licenses this file to You under the Apache License, Version 2.0
#  (the "License"); you may not use this file except in compliance with
#  the License.  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

require 'spec_helper'
require 'whimsy/sitestandards'

describe SiteStandards do
  describe 'check for links to a security page' do
    valid = SiteStandards::COMMON_CHECKS['security'][SiteStandards::CHECK_VALIDATE]
    it "should recognize an absolute link to the ASF-wide page" do
      expect("https://www.apache.org/security").to match(valid)
      expect("https://apache.org/security").to match(valid)
      expect("https://www.apache.org/security/").to match(valid)
      expect("https://apache.org/security/").to match(valid)
    end
    it "should recognize an absolute link to a project-specific page" do
      expect("https://ofbiz.apache.org/download.html#security").to match(valid)
      expect("https://cwiki.apache.org/confluence/display/SPAMASSASSIN/SecurityPolicy").to match(valid)
      expect("https://tvm.apache.org/docs/reference/security.html").to match(valid)
      expect("https://zookeeper.apache.org/security.html").to match(valid)
    end
    it "should recognize a relative link to a project-specific page" do
      expect("/security.html").to match(valid)
    end
    it "should reject other links" do
      expect("https://www.apache.org/legal/release-policy.html").not_to match(valid)
      expect("/downloads.html").not_to match(valid)
    end
  end

  describe 'check for links to a privacy policy' do
    valid = SiteStandards::COMMON_CHECKS['privacy'][SiteStandards::CHECK_VALIDATE]
    it "should recognize the canonical privacy policy URL" do
      expect("https://privacy.apache.org/policies/privacy-policy-public.html").to match(valid)
    end
    it "should recognize the legacy foundation privacy URL" do
      expect("https://www.apache.org/foundation/policies/privacy.html").to match(valid)
      expect("https://apache.org/foundation/policies/privacy.html").to match(valid)
    end
    it "should recognize project-level privacy pages on *.apache.org" do
      expect("https://beam.apache.org/privacy_policy").to match(valid)
      expect("https://karaf.apache.org/privacy.html").to match(valid)
      expect("https://pig.apache.org/privacypolicy.html").to match(valid)
      expect("https://systemds.apache.org/privacy-policy").to match(valid)
      expect("https://hudi.apache.org/asf/privacy").to match(valid)
      expect("https://cwiki.apache.org/confluence/display/KNOX/Privacy+Policy").to match(valid)
    end
    it "should reject non-ASF privacy pages" do
      expect("https://policies.google.com/privacy").not_to match(valid)
      expect("https://github.com/apache/privacy-website").not_to match(valid)
      expect("https://example.com/privacy-policy.html").not_to match(valid)
    end
  end
end
