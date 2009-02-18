require "#{File.dirname(__FILE__)}/../test_helper"

class CacheObserverMiembrosTest < ActionController::IntegrationTest
  def setup
    ActionController::Base.perform_caching             = true
    host! App.domain
  end
  
  def atest_should_clear_ultimos_registros_box_on_newuser_confirmation
    assert_cache_exists 'common/miembros/_rightside/ultimos_registros'
    u = User.find_by_login('unconfirmed_user')
    assert_not_nil u
    assert_equal User::ST_UNCONFIRMED, u.state
    post "/cuenta/cuenta/do_confirmar", { :k => u.validkey, :email => u.email }
    assert_response :redirect, @response.body
    u.reload
    assert_equal User::ST_SHADOW, u.state
    assert_cache_dont_exist 'common/miembros/index/ultimos_registros'
    #assert @response.body.find(u.login) != -1
  end
  
  def test_should_clear_firmas_on_new_signature
    @u1 = User.find(1)
    get "/miembros/#{@u1.login}/firmas"
    assert_response :success, @response.body
    assert_cache_exists "/common/miembros/#{@u1.id % 1000}/#{@u1.id}/firmas"
    sym_login('mrcheater', 'mrcheaterpass')
    post "/miembros/#{@u1.login}/update_signature", { :profile_signature => { :signature => 'mmmmmmmuermo' } }
    assert_response :redirect
    assert_cache_dont_exist "/miembros/#{@u1.id % 1000}/#{@u1.id}/firmas"
  end
  
  def test_should_clear_firmas_on_updating_signature
    test_should_clear_firmas_on_new_signature
    get "/miembros/#{@u1.login}/firmas"
    assert_response :success
    assert_cache_exists "/common/miembros/#{@u1.id % 1000}/#{@u1.id}/firmas"
    post "/miembros/#{@u1.login}/update_signature", { :profile_signature => { :signature => 'mmmmmmmuermota' } }
    assert_response :redirect
    assert_cache_dont_exist "/miembros/#{@u1.id % 1000}/#{@u1.id}/firmas"
  end
  
  def test_should_clear_content_stats_on_new_comment
    sym_login 'superadmin', 'lalala'
    @u1 = User.find(1)
    n = News.find(:published, :limit => 1)[0]
    get "/miembros/#{@u1.login}/estadisticas"
    assert_cache_exists "/common/miembros/#{@u1.id % 1000}/#{@u1.id}/contents_stats"
    post_comment_on n
    assert_cache_dont_exist "/common/miembros/#{@u1.id % 1000}/#{@u1.id}/contents_stats"
  end
  
  # TODO esta sobra aquí
  def test_member_should_work_with_url_with_dot
    u = User.create({:login => 'dil.', :email => 'dil@dil.com', :ipaddr => '0.0.0.0', :lastseen_on => Time.now})
    assert_not_nil User.find_by_login('dil.') # true, u.save, u.errors.full_messages
    get "/miembros/dil."
    assert_response :success, @response.body
    assert_template 'miembros/member'
  end
  
  def test_member_should_work_with_url_with_comilla
    u = User.create({:login => '~(DMT)~Rooney', :email => 'dil@dil.com', :ipaddr => '0.0.0.0', :lastseen_on => Time.now})
    assert_not_nil User.find_by_login('~(DMT)~Rooney') # true, u.save, u.errors.full_messages
    get "/miembros/~(DMT)~Rooney"
    assert_response :success, @response.body
    assert_template 'miembros/member'
  end
  
  def test_member_should_work_with_url_with_exclamation
    u = User.create({:login => '3lr0hr', :email => 'dil@dil.com', :ipaddr => '0.0.0.0', :lastseen_on => Time.now})
    u.reload
    u.login = '3lr0h!r'
    u.save
    assert_not_nil User.find_by_login('3lr0h!r') # true, u.save, u.errors.full_messages
    get "/miembros/3lr0h!r"
    assert_response :success, @response.body
    assert_template 'miembros/member'
  end
  
  def test_should_clear_miembros_cache_after_friend_accepts_friendship
    
    @u1 = User.find_by_login('superadmin')
    ff = Friendship.find_between(@u1, User.find_by_login('panzer'))
    ff.destroy if ff
    @cache_path = "/common/miembros/#{@u1.id % 1000}/#{@u1.id}/friends_#{Time.now.to_i/(86400*30)}"
    get '/miembros/superadmin/amigos'
    assert_response :success, @response.body
    assert_cache_exists @cache_path
    sym_login :superadmin, :lalala
    assert_count_increases(Friendship) do
      post '/cuenta/amigos/iniciar_amistad/panzer'
      assert_response :redirect
    end
    @u1.reload
    assert_equal false, User.find_by_login('panzer').is_friend_of?(@u1)
    
    sym_login :panzer, :lelele
    post "/cuenta/amigos/aceptar_amistad/#{@u1.login}"
    assert_response :redirect, @response.body
    @u1.reload
    assert_equal true, User.find_by_login('panzer').is_friend_of?(@u1)
    #    @u1.friends<< Friend.find_by_login('panzer')
    assert_cache_dont_exist @cache_path
  end
  
  def test_should_clear_miembros_cache_after_deleting_a_friend
    test_should_clear_miembros_cache_after_friend_accepts_friendship
    get '/miembros/superadmin/amigos'
    assert_response :success, @response.body
    assert_cache_exists @cache_path
    post '/cuenta/amigos/cancelar_amistad/superadmin'
    assert_response :redirect, @response.body
    assert_equal false, User.find_by_login('panzer').is_friend_of?(@u1)
    assert_cache_dont_exist @cache_path
  end
  
  def teardown
    ActionController::Base.perform_caching             = false
  end
end
