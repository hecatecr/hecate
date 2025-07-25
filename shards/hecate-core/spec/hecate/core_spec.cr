require "../spec_helper"

describe Hecate::Core do
  it "has a version number" do
    Hecate::Core::VERSION.should eq("0.1.0")
  end

  it "is defined as a module" do
    # Simply accessing the module verifies it exists
    Hecate::Core::VERSION.should_not be_nil
  end
end
