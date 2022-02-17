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
require 'whimsy/asf'

set_svnroot # need access to listing file

describe ASF::EmeritusFiles do
    it "listnames should return array of size 1" do
        res = ASF::EmeritusFiles.listnames
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(1)
        expect(res.first).to eq('emeritus1.txt')
    end
    it "find Person.find('nemo') should return nil" do
        res = ASF::EmeritusFiles.find(ASF::Person.find('nemo'))
        expect(res).to eq(nil)
    end
    it "find Person.find('emeritus1') should return emeritus1.txt" do
        res = ASF::EmeritusFiles.find(ASF::Person.find('emeritus1'))
        expect(res).to eq('emeritus1.txt')
    end
    it "findpath Person.find('emeritus1') should return svnpath and file " do
        res = ASF::EmeritusFiles.findpath(ASF::Person.find('emeritus1'))
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(2)
        expect(res[0]).to end_with('/emeritus1.txt')
        expect(res[1]).to eq('emeritus1.txt')
    end
    it "findpath Person.find('emeritus1') should return same path as path!(file) " do
        res = ASF::EmeritusFiles.findpath(ASF::Person.find('emeritus1'))
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(2)
        svnpath = res[0]
        file = res[1]
        expect(svnpath).to end_with('/emeritus1.txt')
        expect(file).to eq('emeritus1.txt')
        path = ASF::EmeritusFiles.svnpath!(file)
        expect(path).to eq(svnpath)
    end
end

describe ASF::EmeritusReinstatedFiles do
    it "listnames should return array of size 1" do
        res = ASF::EmeritusReinstatedFiles.listnames
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(1)
        expect(res.first).to eq('emeritus2.txt')
    end
    it "find Person.find('nemo') should return nil" do
        res = ASF::EmeritusReinstatedFiles.find(ASF::Person.find('nemo'))
        expect(res).to eq(nil)
    end
    it "find Person.find('emeritus2') should return emeritus2.txt" do
        res = ASF::EmeritusReinstatedFiles.find(ASF::Person.find('emeritus2'))
        expect(res).to eq('emeritus2.txt')
    end
end

describe ASF::EmeritusRequestFiles do
    it "listnames should return array of size 1" do
        res = ASF::EmeritusRequestFiles.listnames
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(1)
        expect(res.first).to eq('emeritus3.txt')
    end
    it "find Person.find('nemo') should return nil" do
        res = ASF::EmeritusRequestFiles.find(ASF::Person.find('nemo'))
        expect(res).to eq(nil)
    end
    it "find Person.find('emeritus3') should return emeritus3.txt" do
        res = ASF::EmeritusRequestFiles.find(ASF::Person.find('emeritus3'))
        expect(res).to eq('emeritus3.txt')
    end
end

describe ASF::EmeritusRescindedFiles do
    it "listnames should return array of size 1" do
        res = ASF::EmeritusRescindedFiles.listnames
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(1)
        expect(res.first).to eq('emeritus4.txt')
    end
    it "find Person.find('nemo') should return nil" do
        res = ASF::EmeritusRescindedFiles.find(ASF::Person.find('nemo'))
        expect(res).to eq(nil)
    end
    it "find Person.find('emeritus4') should return emeritus4.txt" do
        res = ASF::EmeritusRescindedFiles.find(ASF::Person.find('emeritus4'))
        expect(res).to eq('emeritus4.txt')
    end
    it "findpath Person.find('emeritus4') should return svnpath and file " do
        res = ASF::EmeritusRescindedFiles.findpath(ASF::Person.find('emeritus4'))
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(2)
        expect(res[0]).to end_with('/emeritus4.txt')
        expect(res[1]).to eq('emeritus4.txt')
    end
    it "findpath Person.find('emeritus4') should return same path as path!(file) " do
        res = ASF::EmeritusRescindedFiles.findpath(ASF::Person.find('emeritus4'))
        expect(res).to be_kind_of(Array)
        expect(res.size).to eq(2)
        svnpath = res[0]
        file = res[1]
        expect(svnpath).to end_with('/emeritus4.txt')
        expect(file).to eq('emeritus4.txt')
        path = ASF::EmeritusRescindedFiles.svnpath!(file)
        expect(path).to eq(svnpath)
    end
end
