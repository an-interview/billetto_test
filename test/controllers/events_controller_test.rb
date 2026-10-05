require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  test "lists events" do
    get events_url

    assert_response :success
    assert_select "h1", "Events"
    assert_select ".event__title", minimum: 2
  end

  test "shows title, date, image and description" do
    get events_url

    assert_select ".event__title", text: /Rails Meetup/
    assert_select ".event__date", minimum: 1
    assert_select "img.event__image", minimum: 1
    assert_select ".event__description", minimum: 1
  end

  test "orders events by start date" do
    get events_url

    titles = css_select(".event__title").map(&:text).map(&:strip)
    expected = Event.ordered.map(&:title)

    assert_equal expected, titles
  end

  test "root renders the listing" do
    get root_url

    assert_response :success
    assert_select ".events__list"
  end

  test "renders the empty state without events" do
    Event.delete_all

    get events_url

    assert_response :success
    assert_select ".events__empty"
  end
end
