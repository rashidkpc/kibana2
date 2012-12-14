require "spec_helper"

require "KibanaConfig"
require "client_request"

describe ClientRequest do
  context "#initialize" do
    it "should parse empty request" do
      h = {"search"=>"", "fields"=>[], "offset"=>0, "timeframe"=>900, "graphmode"=>"count"}
      b64_hash = Base64.encode64(JSON.generate(h))

      reference_time = Time.parse("2012-11-02 15:30:00 +0100")
      Time.stub(:now).and_return(reference_time)

      cr = ClientRequest.new(b64_hash)

      cr.search.should == ""
      cr.fields.should == ["@message"]
      cr.offset.should == 0

      cr.from.should == (reference_time - 900)
      cr.to.should == reference_time
    end

    it "should split search parameter" do
      h = {"search"=>"foo|bar", "fields"=>[], "offset"=>0, "timeframe"=>900, "graphmode"=>"count"}
      b64_hash = Base64.encode64(JSON.generate(h))

      cr = ClientRequest.new(b64_hash)

      cr.search.should == "foo"
    end

    it "should set index to 0 if not given" do
      h = {"search"=>"", "fields"=>[], "timeframe"=>900, "graphmode"=>"count"}
      b64_hash = Base64.encode64(JSON.generate(h))

      cr = ClientRequest.new(b64_hash)

      cr.offset.should == 0
    end

    it "should set index to value if given" do
      h = {"search"=>"", "fields"=>[], "offset" => 42, "timeframe"=>900, "graphmode"=>"count"}
      b64_hash = Base64.encode64(JSON.generate(h))

      cr = ClientRequest.new(b64_hash)

      cr.offset.should == 42
    end

    it "should set field" do
      h = {"search"=>"", "fields"=>["foo", "bar"], "offset" => 42, "timeframe"=>900, "graphmode"=>"count"}
      b64_hash = Base64.encode64(JSON.generate(h))

      cr = ClientRequest.new(b64_hash)

      cr.fields.should == ["foo", "bar"]
    end

    it "should set to and from to custom values" do
      from_time = Time.parse("2012-11-02T14:10:00+01:00")
      to_time = Time.parse("2012-11-02T14:20:00+01:00")

      h = {
        "search"=>"",
        "fields"=>[],
        "offset" => 42,
        "timeframe"=>"custom",
        "graphmode"=>"count",
        "time" => {
          "from" => from_time.iso8601,
          "to" => to_time.iso8601
        }
      }

      b64_hash = Base64.encode64(JSON.generate(h))

      cr = ClientRequest.new(b64_hash)

      cr.from.should == from_time
      cr.to.should == to_time
    end

    it "should set to and from to custom values" do
      h = {"search"=>"", "fields"=>[], "offset"=>0, "timeframe"=>"all", "graphmode"=>"count"}

      b64_hash = Base64.encode64(JSON.generate(h))

      reference_time = Time.parse("2012-11-02 15:30:00 +0100")
      Time.stub(:now).and_return(reference_time)

      cr = ClientRequest.new(b64_hash)

      cr.from.should == Time.at(0)
      cr.to.should == reference_time
    end

    it "should set to and from to Time.now-timeframe" do
      h = {"search"=>"", "fields"=>[], "offset"=>0, "timeframe"=>10, "graphmode"=>"count"}

      b64_hash = Base64.encode64(JSON.generate(h))

      reference_time = Time.parse("2012-11-02 15:30:00 +0100")
      Time.stub(:now).and_return(reference_time)

      cr = ClientRequest.new(b64_hash)

      cr.from.should == (reference_time - 10)
      cr.to.should == reference_time
    end

    it "should fallback to Time.now-15m if timeframe is set to unexpected value" do
      h = {"search"=>"", "fields"=>[], "offset"=>0, "timeframe"=>"foobar", "graphmode"=>"count"}
      b64_hash = Base64.encode64(JSON.generate(h))

      reference_time = Time.parse("2012-11-02 15:30:00 +0100")
      Time.stub(:now).and_return(reference_time)

      cr = ClientRequest.new(b64_hash)

      cr.from.should == (reference_time - KibanaConfig::Fallback_interval)
      cr.to.should == reference_time
    end
  end

  context "#hash" do
    it "should convert Hash to encoded hash" do
      h = {"search"=>"", "fields"=>[], "offset"=>0, "timeframe"=>"foobar", "graphmode"=>"count"}
      b64_hash = Base64.encode64(JSON.generate(h))

      ClientRequest.hash(h).should == b64_hash
    end
  end
end
