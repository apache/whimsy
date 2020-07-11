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
end
