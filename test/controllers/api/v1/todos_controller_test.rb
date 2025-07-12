require "test_helper"

class Api::V1::TodosControllerTest < ActionDispatch::IntegrationTest
  test "should get suggest" do
    get api_v1_todos_suggest_url
    assert_response :success
  end
end
