require 'test_helper'
require File.dirname(__FILE__) + '/../test_functional_content_helper'

class ReviewsControllerTest < ActionController::TestCase
  test_common_content_crud :name => 'Review', :form_vars => {:title => 'footapang', :description => 'bartapang', :main => 'oooo'}, :root_terms => 1
end
