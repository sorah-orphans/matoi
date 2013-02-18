require 'spec_helper'
require 'matoi/circular_array'

describe Matoi::CircularArray do
  let(:size) { 3 }
  subject(:carray) { described_class.new(size) }

  describe "#push" do
    context "with single element" do
      context "when not overflows" do
        before do
          subject.push(1)
        end

        it { should == [1] }
      end

      context "when overflows" do
        before do
          subject.push(1)
          subject.push(2)
          subject.push(3)
          subject.push(4)
        end

        it { should == [2, 3, 4] }
      end
    end

    context "with multiple elements" do
      context "when not overflows" do
        before do
          subject.push(1, 2, 3)
        end

        it { should == [1, 2, 3] }
      end

      context "when overflows" do
        before do
          subject.push(1, 2, 3)
          subject.push(4, 5)
        end

        it { should == [3, 4, 5] }
      end
    end
  end
end
