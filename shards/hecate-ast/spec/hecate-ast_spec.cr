require "./spec_helper"

describe "Hecate::AST" do
  it "has a VERSION" do
    Hecate::AST::VERSION.should eq("0.1.0")
  end

  it "provides convenience methods for diagnostics" do
    # Just verify these methods exist
    Hecate::AST.error("test").should be_a(Hecate::Core::DiagnosticBuilder)
    Hecate::AST.warning("test").should be_a(Hecate::Core::DiagnosticBuilder)
    Hecate::AST.info("test").should be_a(Hecate::Core::DiagnosticBuilder)
    Hecate::AST.hint("test").should be_a(Hecate::Core::DiagnosticBuilder)
  end
end