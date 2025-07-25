require "../../spec_helper"

describe Hecate::Core::Span do
  describe "#initialize" do
    it "creates valid span" do
      span = Hecate::Core::Span.new(1_u32, 10, 20)
      span.source_id.should eq(1_u32)
      span.start_byte.should eq(10)
      span.end_byte.should eq(20)
    end

    it "allows zero-length spans" do
      span = Hecate::Core::Span.new(1_u32, 10, 10)
      span.start_byte.should eq(10)
      span.end_byte.should eq(10)
    end

    it "raises ArgumentError for invalid spans" do
      expect_raises(ArgumentError, "Invalid span: end_byte (5) cannot be less than start_byte (10)") do
        Hecate::Core::Span.new(1_u32, 10, 5)
      end
    end
  end

  describe "#length" do
    it "calculates span length" do
      span = Hecate::Core::Span.new(1_u32, 10, 20)
      span.length.should eq(10)
    end

    it "returns 0 for zero-length spans" do
      span = Hecate::Core::Span.new(1_u32, 10, 10)
      span.length.should eq(0)
    end

    it "calculates single-byte span length" do
      span = Hecate::Core::Span.new(1_u32, 10, 11)
      span.length.should eq(1)
    end
  end

  describe "#to_s" do
    it "formats span information" do
      span = Hecate::Core::Span.new(2_u32, 10, 20)
      span.to_s.should eq("Span(source=2, 10..20)")
    end
  end

  describe "#==" do
    it "compares spans for equality" do
      span1 = Hecate::Core::Span.new(1_u32, 10, 20)
      span2 = Hecate::Core::Span.new(1_u32, 10, 20)
      span3 = Hecate::Core::Span.new(2_u32, 10, 20)
      span4 = Hecate::Core::Span.new(1_u32, 10, 21)

      (span1 == span2).should be_true
      (span1 == span3).should be_false # Different source
      (span1 == span4).should be_false # Different end
    end
  end

  describe "#contains?" do
    it "checks if byte offset is within span" do
      span = Hecate::Core::Span.new(1_u32, 10, 20)

      span.contains?(9).should be_false
      span.contains?(10).should be_true # Start is inclusive
      span.contains?(15).should be_true
      span.contains?(19).should be_true
      span.contains?(20).should be_false # End is exclusive
      span.contains?(21).should be_false
    end

    it "handles zero-length spans" do
      span = Hecate::Core::Span.new(1_u32, 10, 10)
      span.contains?(10).should be_false
    end
  end

  describe "#overlaps?" do
    it "detects overlapping spans" do
      span1 = Hecate::Core::Span.new(1_u32, 10, 20)
      span2 = Hecate::Core::Span.new(1_u32, 15, 25)
      span3 = Hecate::Core::Span.new(1_u32, 20, 30)
      span4 = Hecate::Core::Span.new(1_u32, 5, 15)

      span1.overlaps?(span2).should be_true  # Partial overlap
      span1.overlaps?(span3).should be_false # Adjacent, no overlap
      span1.overlaps?(span4).should be_true  # Partial overlap
    end

    it "returns false for spans from different sources" do
      span1 = Hecate::Core::Span.new(1_u32, 10, 20)
      span2 = Hecate::Core::Span.new(2_u32, 10, 20)

      span1.overlaps?(span2).should be_false
    end

    it "handles contained spans" do
      span1 = Hecate::Core::Span.new(1_u32, 10, 30)
      span2 = Hecate::Core::Span.new(1_u32, 15, 25)

      span1.overlaps?(span2).should be_true
      span2.overlaps?(span1).should be_true
    end
  end

  describe "#merge" do
    it "merges overlapping spans" do
      span1 = Hecate::Core::Span.new(1_u32, 10, 20)
      span2 = Hecate::Core::Span.new(1_u32, 15, 25)

      merged = span1.merge(span2)
      merged.source_id.should eq(1_u32)
      merged.start_byte.should eq(10)
      merged.end_byte.should eq(25)
    end

    it "merges non-overlapping spans" do
      span1 = Hecate::Core::Span.new(1_u32, 10, 20)
      span2 = Hecate::Core::Span.new(1_u32, 30, 40)

      merged = span1.merge(span2)
      merged.start_byte.should eq(10)
      merged.end_byte.should eq(40)
    end

    it "handles same span merge" do
      span = Hecate::Core::Span.new(1_u32, 10, 20)
      merged = span.merge(span)

      merged.should eq(span)
    end

    it "raises error for different source spans" do
      span1 = Hecate::Core::Span.new(1_u32, 10, 20)
      span2 = Hecate::Core::Span.new(2_u32, 10, 20)

      expect_raises(ArgumentError, "Cannot merge spans from different sources") do
        span1.merge(span2)
      end
    end
  end
end
