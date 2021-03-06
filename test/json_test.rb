require 'test_helper'
require 'representable/json'

module JsonTest
  class APITest < MiniTest::Spec
    Json = Representable::JSON
    Def = Representable::Definition
    
    describe "JSON module" do
      before do
        @Band = Class.new do
          include Representable::JSON
          representable_property :name
          representable_property :label
          
          def initialize(name=nil)
            self.name = name if name
          end
        end
        
        @band = @Band.new
      end
    
    
      describe ".from_json" do
        it "is delegated to #from_json" do
          block = lambda {|bind|}
          @Band.any_instance.expects(:from_json).with("{}", "yo") # FIXME: how to expect block?
          @Band.from_json("{}", "yo", &block)
        end
      end
      
      
      describe ".from_hash" do
        it "is delegated to #from_hash" do
          block = lambda {|bind|}
          @Band.any_instance.expects(:from_hash).with("{}", "yo") # FIXME: how to expect block?
          @Band.from_hash("{}", "yo", &block)
        end
      end
      
      
      describe "#from_json" do
        before do
          @band = @Band.new
          @json  = {:name => "Nofx", :label => "NOFX"}.to_json
        end
        
        it "parses JSON and assigns properties" do
          @band.from_json(@json)
          assert_equal ["Nofx", "NOFX"], [@band.name, @band.label]
        end
        
        it "forwards block to #from_hash" do
          @band.from_json(@json) do |name|
            name == :name
          end
          
          assert_equal ["Nofx", nil], [@band.name, @band.label]
        end
      end
      
      
      describe "#from_hash" do
        before do
          @band = @Band.new
          @hash  = {"name" => "Nofx", "label" => "NOFX"}
        end
        
        it "receives hash and assigns properties" do
          @band.from_hash(@hash)
          assert_equal ["Nofx", "NOFX"], [@band.name, @band.label]
        end
        
        it "forwards block to #update_properties_from" do
          @band.from_hash(@hash) do |name|
            name == :name
          end
          
          assert_equal ["Nofx", nil], [@band.name, @band.label]
        end
        
        it "respects :wrap option" do
          @band.from_hash({"band" => {"name" => "This Is A Standoff"}}, :wrap => :band)
          assert_equal "This Is A Standoff", @band.name
        end
          
        it "respects :wrap option over representation_wrap" do
          @Band.class_eval do
            self.representation_wrap = :group 
          end
          @band.from_hash({"band" => {"name" => "This Is A Standoff"}}, :wrap => :band)
          assert_equal "This Is A Standoff", @band.name
        end
      end
      
      
      describe "#to_json" do
        it "delegates to #to_hash and returns string" do
          assert_equal "{\"name\":\"Rise Against\"}", @Band.new("Rise Against").to_json
        end
        
        it "forwards block to #to_hash" do
          band = @Band.new
          band.name  = "The Guinea Pigs"
          band.label = "n/a"
          json = band.to_json do |name|
            name == :name
          end
          
          assert_equal "{\"name\":\"The Guinea Pigs\"}", json
        end
      end
      
      
      describe "#to_hash" do
        it "returns unwrapped hash" do
          hash = @Band.new("Rise Against").to_hash
          assert_equal({"name"=>"Rise Against"}, hash)
        end
        
        it "respects #representation_wrap=" do
          @Band.representation_wrap = :group
          assert_equal({:group=>{"name"=>"Rise Against"}}, @Band.new("Rise Against").to_hash)
        end
        
        it "respects :wrap option" do
          assert_equal({:band=>{"name"=>"NOFX"}}, @Band.new("NOFX").to_hash(:wrap => :band))
        end
          
        it "respects :wrap option over representation_wrap" do
          @Band.class_eval do
            self.representation_wrap = :group 
          end
          assert_equal({:band=>{"name"=>"Rise Against"}}, @Band.new("Rise Against").to_hash(:wrap => :band))
        end
      end
        
      describe "#binding_for_definition" do
        it "returns ObjectBinding" do
          assert_kind_of Json::ObjectBinding, @band.binding_for_definition(Def.new(:band, :as => Hash))
        end
        
        it "returns TextBinding" do
          assert_kind_of Json::TextBinding, @band.binding_for_definition(Def.new(:band))
        end
      end
      
      describe "#representable_bindings" do
        it "returns bindings for each property" do
          assert_equal 2, @band.send(:representable_bindings).size
          assert_equal "name", @band.send(:representable_bindings).first.definition.name
        end
      end
    end
  end

  class PropertyTest < MiniTest::Spec
    describe "representable_property :name" do
      class Band
        include Representable::JSON
        representable_property :name
      end
      
      it "#from_json creates correct accessors" do
        band = Band.from_json({:name => "Bombshell Rocks"}.to_json)
        assert_equal "Bombshell Rocks", band.name
      end
      
      it "#to_json serializes correctly" do
        band = Band.new
        band.name = "Cigar"
        
        assert_equal '{"name":"Cigar"}', band.to_json
      end
    end
    
    describe ":as => Item" do
      class Label
        include Representable::JSON
        representable_property :name
      end
      
      class Album
        include Representable::JSON
        representable_property :label, :as => Label
      end
      
      it "#from_json creates one Item instance" do
        album = Album.from_json('{"label":{"name":"Fat Wreck"}}')
        assert_equal "Fat Wreck", album.label.name
      end
      
      it "#to_json serializes" do
        label = Label.new; label.name = "Fat Wreck"
        album = Album.new; album.label = label
        
        assert_equal '{"label":{"name":"Fat Wreck"}}', album.to_json
      end
      
      describe ":different_name, :as => Label" do
        before do
          @Album = Class.new do
            include Representable::JSON
            representable_property :seller, :as => Label
          end
        end
        
        it "#to_xml respects the different name" do
          label = Label.new; label.name = "Fat Wreck"
          album = @Album.new; album.seller = label
          
          assert_equal "{\"seller\":{\"name\":\"Fat Wreck\"}}", album.to_json(:wrap => false)
        end
      end
    end
    
    describe ":from => :songName" do
      class Song
        include Representable::JSON
        representable_property :name, :from => :songName
      end
      
      it "respects :from in #from_json" do
        song = Song.from_json({:songName => "Run To The Hills"}.to_json)
        assert_equal "Run To The Hills", song.name
      end
      
      it "respects :from in #to_json" do
        song = Song.new; song.name = "Run To The Hills"
        assert_equal '{"songName":"Run To The Hills"}', song.to_json
      end
    end
    
    describe ":default => :value" do
      before do
        @Album = Class.new do
        include Representable::JSON
        representable_property :name, :default => "30 Years Live"
      end
    end
      
    describe "#from_json" do
      it "uses default when property nil in doc" do
        album = @Album.from_json({}.to_json)
        assert_equal "30 Years Live", album.name
      end
      
      it "uses value from doc when present" do
        album = @Album.from_json({:name => "Live At The Wireless"}.to_json)
        assert_equal "Live At The Wireless", album.name
      end
      
      it "uses value from doc when empty string" do
        album = @Album.from_json({:name => ""}.to_json)
        assert_equal "", album.name
      end
    end
    
    describe "#to_json" do
      it "uses default when not available in object" do
        assert_equal "{\"name\":\"30 Years Live\"}", @Album.new.to_json
      end
      
      it "uses value from represented object when present" do
        album = @Album.new
        album.name = "Live At The Wireless"
        assert_equal "{\"name\":\"Live At The Wireless\"}", album.to_json
      end
      
      it "uses value from represented object when emtpy string" do
        album = @Album.new
        album.name = ""
        assert_equal "{\"name\":\"\"}", album.to_json
      end
    end
  end
end


  class CollectionTest < MiniTest::Spec
    describe "representable_collection :name" do
      class CD
        include Representable::JSON
        representable_collection :songs
      end
      
      it "#from_json creates correct accessors" do
        cd = CD.from_json({:songs => ["Out in the cold", "Microphone"]}.to_json)
        assert_equal ["Out in the cold", "Microphone"], cd.songs
      end
    
      it "#to_json serializes correctly" do
        cd = CD.new
        cd.songs = ["Out in the cold", "Microphone"]
        
        assert_equal '{"songs":["Out in the cold","Microphone"]}', cd.to_json
      end
    end
    
    describe "representable_collection :name, :as => Band" do
      class Band
        include Representable::JSON
        representable_property :name
        
        def initialize(name="")
          self.name = name
        end
      end
      
      class Compilation
        include Representable::JSON
        representable_collection :bands, :as => Band
      end
      
      describe "#from_json" do
        it "pushes collection items to array" do
          cd = Compilation.from_json({:bands => [
            {:name => "Cobra Skulls"},
            {:name => "Diesel Boy"}]}.to_json)
          assert_equal ["Cobra Skulls", "Diesel Boy"], cd.bands.map(&:name).sort
        end
        
        it "creates emtpy array per default" do
          cd = Compilation.from_json({:compilation => {}}.to_json)
          assert_equal [], cd.bands
        end
      end
      
      it "responds to #to_json" do
        cd = Compilation.new
        cd.bands = [Band.new("Diesel Boy"), Band.new("Bad Religion")]
        
        assert_equal '{"bands":[{"name":"Diesel Boy"},{"name":"Bad Religion"}]}', cd.to_json
      end
    end
    
    
    describe ":from => :songList" do
      class Songs
        include Representable::JSON
        representable_collection :tracks, :from => :songList
      end
      
      it "respects :from in #from_json" do
        songs = Songs.from_json({:songList => ["Out in the cold", "Microphone"]}.to_json)
        assert_equal ["Out in the cold", "Microphone"], songs.tracks
      end
    
      it "respects option in #to_json" do
        songs = Songs.new
        songs.tracks = ["Out in the cold", "Microphone"]
        
        assert_equal '{"songList":["Out in the cold","Microphone"]}', songs.to_json
      end
    end
  end
end
