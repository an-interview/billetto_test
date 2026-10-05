require "test_helper"

class ObjectRepositoryTest < ActiveSupport::TestCase
  class Widget
    include ObjectRepository::HasTypeid
    has_typeid :widget

    attr_reader :id

    def initialize(id)
      @id = id
    end

    def self.find(id)
      new(id)
    end
  end

  test "registers the type id and exposes tid" do
    assert_equal "widget_42", Widget.new(42).tid
  end

  test "finds by tid" do
    widget = ObjectRepository.find("widget_7")

    assert_instance_of Widget, widget
    assert_equal "7", widget.id
  end

  test "raises for unknown type id" do
    assert_raises(ObjectRepository::UnknownType) { ObjectRepository.find("nope_1") }
  end
end
