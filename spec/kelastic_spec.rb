require "spec_helper"

require "KibanaConfig"
require "kelastic"

describe "Kelastic" do
  context "#initialize" do
    it "should construct correct url" do
      Kelastic.should_receive(:run).and_return({})

      k = Kelastic.new("foo", "my_index")

      k.url.should == "http://localhost:9200/my_index/_search"
    end

    it "should work convert response" do
      Kelastic.should_receive(:run).and_return({})

      k = Kelastic.new("foo", "my_index")

      response = k.response
      response.should be_a_kind_of Hash

      response.should have_key "kibana"
      response["kibana"]["index"].should == "my_index"
    end
  end

  context "#all_indices" do
    def stub_http_get_and_return_body(mock_body)
      http = Net::HTTP.new("localhost",9200)
      Net::HTTP.should_receive(:new).with('localhost',9200).and_return(http)
      response = double("response")
      response.stub(:body) {
        mock_body
      }
      http.should_receive(:request).with(anything()).and_return(response)
    end
    it "should return list of indices" do
      stub_http_get_and_return_body(%Q{
          {"logstash-2012.11.06":{"aliases":{}}}
      })

      Kelastic.all_indices.should == ["logstash-2012.11.06"]
    end

    it "should return list of indices and aliases" do
      stub_http_get_and_return_body(%Q{
          {"logstash-2012.11.06":{"aliases":{ "foo": "bar", "baz": "doh"}}}
      })

      Kelastic.all_indices.sort.should == ["baz", "foo", "logstash-2012.11.06"]
    end
  end

  context "#date_range" do
    it "should return list of 3 dates" do
      result = Kelastic.date_range(Time.parse("2012-11-01 17:30:00 +0100"), Time.parse("2012-11-03 17:30:00 +0100"))

      result.size.should == 3
      result[0].to_s.should == "2012-11-01"
      result[1].to_s.should == "2012-11-02"
      result[2].to_s.should == "2012-11-03"
    end

    it "should return list with only todays date" do
      result = Kelastic.date_range(Time.parse("2012-11-01 17:00:00 +0100"), Time.parse("2012-11-01 18:00:00 +0100"))

      result.size.should == 1
      result[0].to_s.should == "2012-11-01"
    end
  end

  context "#index_range" do
    it "should work with to and from coverted by indices" do
      Kelastic.should_receive(:all_indices).and_return(["logstash-2012.11.01","logstash-2012.11.02", "logstash-2012.11.03", "logstash-2012.11.04"])

      result = Kelastic.index_range(Time.parse("2012-11-02 17:00:00 +0100"), Time.parse("2012-11-03 18:00:00 +0100"))

      result.size.should == 2
      result[0].should == "logstash-2012.11.03"
      result[1].should == "logstash-2012.11.02"
    end

    it "should work with to date not being present in indices" do
      Kelastic.should_receive(:all_indices).and_return(["logstash-2012.11.01","logstash-2012.11.02"])

      result = Kelastic.index_range(Time.parse("2012-11-02 17:00:00 +0100"), Time.parse("2012-11-08 18:00:00 +0100"))

      result.size.should == 1
      result[0].should == "logstash-2012.11.02"
    end

    it "should work with from date not being present in indices" do
      Kelastic.should_receive(:all_indices).and_return(["logstash-2012.11.01","logstash-2012.11.02"])

      result = Kelastic.index_range(Time.parse("2012-10-15 17:00:00 +0100"), Time.parse("2012-11-01 18:00:00 +0100"))

      result.size.should == 1
      result[0].should == "logstash-2012.11.01"
    end

    it "should work with limit" do
      Kelastic.should_receive(:all_indices).and_return(["logstash-2012.11.01","logstash-2012.11.02", "logstash-2012.11.03", "logstash-2012.11.04"])

      result = Kelastic.index_range(Time.parse("2012-11-02 17:00:00 +0100"), Time.parse("2012-11-04 18:00:00 +0100"), 1)

      result.size.should == 2
      result[0].should == "logstash-2012.11.04"
      result[1].should == "logstash-2012.11.03"
    end

    it "should fallback to Default_index if Smart_index is false" do
      # TODO: find way to mock this config parameter
      KibanaConfig::Smart_index = false

      result = Kelastic.index_range(Time.parse("2012-11-02 17:00:00 +0100"), Time.parse("2012-11-04 18:00:00 +0100"))

      result.should == [ "_all" ]

      KibanaConfig::Smart_index = true
    end
  end

  context "#current_index" do
    it "should return index representing today" do
      expected_index = "logstash-2012.11.01"

      reference_time = Time.parse("2012-11-01 12:00:00 +0100")
      Time.stub(:now).and_return(reference_time)

      Kelastic.current_index.should == [expected_index]
    end

    it "should return Default_index when Smart_index is false" do
      KibanaConfig::Smart_index = false

      Kelastic.current_index.should == "_all"

      KibanaConfig::Smart_index = true
    end
  end
end
