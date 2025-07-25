require "../../spec_helper"

describe Hecate::Core::Position do
  describe "#initialize" do
    it "creates position with line and column" do
      pos = Hecate::Core::Position.new(5, 10)
      pos.line.should eq(5)
      pos.column.should eq(10)
    end

    it "handles zero values" do
      pos = Hecate::Core::Position.new(0, 0)
      pos.line.should eq(0)
      pos.column.should eq(0)
    end
  end

  describe "#display_line" do
    it "converts 0-based line to 1-based for display" do
      pos = Hecate::Core::Position.new(0, 0)
      pos.display_line.should eq(1)

      pos = Hecate::Core::Position.new(5, 10)
      pos.display_line.should eq(6)
    end
  end

  describe "#display_column" do
    it "converts 0-based column to 1-based for display" do
      pos = Hecate::Core::Position.new(0, 0)
      pos.display_column.should eq(1)

      pos = Hecate::Core::Position.new(5, 10)
      pos.display_column.should eq(11)
    end
  end

  describe "#to_s" do
    it "formats as display line:column" do
      pos = Hecate::Core::Position.new(0, 0)
      pos.to_s.should eq("1:1")

      pos = Hecate::Core::Position.new(5, 10)
      pos.to_s.should eq("6:11")
    end
  end

  describe "#==" do
    it "compares positions for equality" do
      pos1 = Hecate::Core::Position.new(5, 10)
      pos2 = Hecate::Core::Position.new(5, 10)
      pos3 = Hecate::Core::Position.new(5, 11)
      pos4 = Hecate::Core::Position.new(6, 10)

      (pos1 == pos2).should be_true
      (pos1 == pos3).should be_false
      (pos1 == pos4).should be_false
    end
  end

  describe "#<=>" do
    it "compares positions by line first, then column" do
      pos1 = Hecate::Core::Position.new(1, 5)
      pos2 = Hecate::Core::Position.new(1, 10)
      pos3 = Hecate::Core::Position.new(2, 0)

      (pos1 <=> pos1).should eq(0)
      (pos1 <=> pos2).should eq(-1)
      (pos2 <=> pos1).should eq(1)
      (pos1 <=> pos3).should eq(-1)
      (pos3 <=> pos1).should eq(1)
    end

    it "enables sorting" do
      positions = [
        Hecate::Core::Position.new(2, 5),
        Hecate::Core::Position.new(1, 10),
        Hecate::Core::Position.new(1, 5),
        Hecate::Core::Position.new(3, 0),
      ]

      sorted = positions.sort
      sorted[0].should eq(Hecate::Core::Position.new(1, 5))
      sorted[1].should eq(Hecate::Core::Position.new(1, 10))
      sorted[2].should eq(Hecate::Core::Position.new(2, 5))
      sorted[3].should eq(Hecate::Core::Position.new(3, 0))
    end
  end
end
