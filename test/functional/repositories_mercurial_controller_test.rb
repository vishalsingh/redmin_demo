# Redmine - project management software
# Copyright (C) 2006-2012  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)

class RepositoriesMercurialControllerTest < ActionController::TestCase
  tests RepositoriesController

  fixtures :projects, :users, :roles, :members, :member_roles,
           :repositories, :enabled_modules

  REPOSITORY_PATH = Rails.root.join('tmp/test/mercurial_repository').to_s
  CHAR_1_HEX = "\xc3\x9c"
  PRJ_ID     = 3
  NUM_REV    = 32

  ruby19_non_utf8_pass =
     (RUBY_VERSION >= '1.9' && Encoding.default_external.to_s != 'UTF-8')

  def setup
    User.current = nil
    @project    = Project.find(PRJ_ID)
    @repository = Repository::Mercurial.create(
                      :project => @project,
                      :url     => REPOSITORY_PATH,
                      :path_encoding => 'ISO-8859-1'
                      )
    assert @repository
    @diff_c_support = true
    @char_1        = CHAR_1_HEX.dup
    @tag_char_1    = "tag-#{CHAR_1_HEX}-00"
    @branch_char_0 = "branch-#{CHAR_1_HEX}-00"
    @branch_char_1 = "branch-#{CHAR_1_HEX}-01"
    if @char_1.respond_to?(:force_encoding)
      @char_1.force_encoding('UTF-8')
      @tag_char_1.force_encoding('UTF-8')
      @branch_char_0.force_encoding('UTF-8')
      @branch_char_1.force_encoding('UTF-8')
    end
  end

  if ruby19_non_utf8_pass
    puts "TODO: Mercurial functional test fails in Ruby 1.9 " +
         "and Encoding.default_external is not UTF-8. " +
         "Current value is '#{Encoding.default_external.to_s}'"
    def test_fake; assert true end
  elsif File.directory?(REPOSITORY_PATH)

    def test_get_new
      @request.session[:user_id] = 1
      @project.repository.destroy
      get :new, :project_id => 'subproject1', :repository_scm => 'Mercurial'
      assert_response :success
      assert_template 'new'
      assert_kind_of Repository::Mercurial, assigns(:repository)
      assert assigns(:repository).new_record?
    end

    def test_show_root
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal 4, assigns(:entries).size
      assert assigns(:entries).detect {|e| e.name == 'images'  && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'sources' && e.kind == 'dir'}
      assert assigns(:entries).detect {|e| e.name == 'README'  && e.kind == 'file'}
      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size > 0
    end

    def test_show_directory
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :show, :id => PRJ_ID, :path => repository_path_hash(['images'])[:param]
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entries)
      assert_equal ['delete.png', 'edit.png'], assigns(:entries).collect(&:name)
      entry = assigns(:entries).detect {|e| e.name == 'edit.png'}
      assert_not_nil entry
      assert_equal 'file', entry.kind
      assert_equal 'images/edit.png', entry.path
      assert_not_nil assigns(:changesets)
      assert assigns(:changesets).size > 0
    end

    def test_show_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [0, '0', '0885933ad4f6'].each do |r1|
        get :show, :id => PRJ_ID, :path => repository_path_hash(['images'])[:param],
            :rev => r1
        assert_response :success
        assert_template 'show'
        assert_not_nil assigns(:entries)
        assert_equal ['delete.png'], assigns(:entries).collect(&:name)
        assert_not_nil assigns(:changesets)
        assert assigns(:changesets).size > 0
      end
    end

    def test_show_directory_sql_escape_percent
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [13, '13', '3a330eb32958'].each do |r1|
        get :show, :id => PRJ_ID,
            :path => repository_path_hash(['sql_escape', 'percent%dir'])[:param],
            :rev => r1
        assert_response :success
        assert_template 'show'

        assert_not_nil assigns(:entries)
        assert_equal ['percent%file1.txt', 'percentfile1.txt'],
                     assigns(:entries).collect(&:name)
        changesets = assigns(:changesets)
        assert_not_nil changesets
        assert assigns(:changesets).size > 0
        assert_equal %w(13 11 10 9), changesets.collect(&:revision)
      end
    end

    def test_show_directory_latin_1_path
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [21, '21', 'adf805632193'].each do |r1|
        get :show, :id => PRJ_ID,
            :path => repository_path_hash(['latin-1-dir'])[:param],
            :rev => r1
        assert_response :success
        assert_template 'show'

        assert_not_nil assigns(:entries)
        assert_equal ["make-latin-1-file.rb",
                      "test-#{@char_1}-1.txt",
                      "test-#{@char_1}-2.txt",
                      "test-#{@char_1}.txt"], assigns(:entries).collect(&:name)
        changesets = assigns(:changesets)
        assert_not_nil changesets
        assert_equal %w(21 20 19 18 17), changesets.collect(&:revision)
      end
    end

    def show_should_show_branch_selection_form
      @repository.fetch_changesets
      @project.reload
      get :show, :id => PRJ_ID
      assert_tag 'form', :attributes => {:id => 'revision_selector', :action => '/projects/subproject1/repository/show'}
      assert_tag 'select', :attributes => {:name => 'branch'},
        :child => {:tag => 'option', :attributes => {:value => 'test-branch-01'}},
        :parent => {:tag => 'form', :attributes => {:id => 'revision_selector'}}
    end

    def test_show_branch
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
       [
          'default',
          @branch_char_1,
          'branch (1)[2]&,%.-3_4',
          @branch_char_0,
          'test_branch.latin-1',
          'test-branch-00',
      ].each do |bra|
        get :show, :id => PRJ_ID, :rev => bra
        assert_response :success
        assert_template 'show'
        assert_not_nil assigns(:entries)
        assert assigns(:entries).size > 0
        assert_not_nil assigns(:changesets)
        assert assigns(:changesets).size > 0
      end
    end

    def test_show_tag
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
       [
        @tag_char_1,
        'tag_test.00',
        'tag-init-revision'
      ].each do |tag|
        get :show, :id => PRJ_ID, :rev => tag
        assert_response :success
        assert_template 'show'
        assert_not_nil assigns(:entries)
        assert assigns(:entries).size > 0
        assert_not_nil assigns(:changesets)
        assert assigns(:changesets).size > 0
      end
    end

    def test_changes
      get :changes, :id => PRJ_ID,
          :path => repository_path_hash(['images', 'edit.png'])[:param]
      assert_response :success
      assert_template 'changes'
      assert_tag :tag => 'h2', :content => 'edit.png'
    end

    def test_entry_show
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
      assert_response :success
      assert_template 'entry'
      # Line 10
      assert_tag :tag => 'th',
                 :content => '10',
                 :attributes => { :class => 'line-num' },
                 :sibling => { :tag => 'td', :content => /WITHOUT ANY WARRANTY/ }
    end

    def test_entry_show_latin_1_path
      [21, '21', 'adf805632193'].each do |r1|
        get :entry, :id => PRJ_ID,
            :path => repository_path_hash(['latin-1-dir', "test-#{@char_1}-2.txt"])[:param],
            :rev => r1
        assert_response :success
        assert_template 'entry'
        assert_tag :tag => 'th',
                 :content => '1',
                 :attributes => { :class => 'line-num' },
                 :sibling => { :tag => 'td',
                               :content => /Mercurial is a distributed version control system/ }
      end
    end

    def test_entry_show_latin_1_contents
      with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
        [27, '27', '7bbf4c738e71'].each do |r1|
          get :entry, :id => PRJ_ID,
              :path => repository_path_hash(['latin-1-dir', "test-#{@char_1}.txt"])[:param],
              :rev => r1
          assert_response :success
          assert_template 'entry'
          assert_tag :tag => 'th',
                 :content => '1',
                 :attributes => { :class => 'line-num' },
                 :sibling => { :tag => 'td',
                               :content => /test-#{@char_1}.txt/ }
        end
      end
    end

    def test_entry_download
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param],
          :format => 'raw'
      assert_response :success
      # File content
      assert @response.body.include?('WITHOUT ANY WARRANTY')
    end

    def test_entry_binary_force_download
      get :entry, :id => PRJ_ID, :rev => 1,
          :path => repository_path_hash(['images', 'edit.png'])[:param]
      assert_response :success
      assert_equal 'image/png', @response.content_type
    end

    def test_directory_entry
      get :entry, :id => PRJ_ID,
          :path => repository_path_hash(['sources'])[:param]
      assert_response :success
      assert_template 'show'
      assert_not_nil assigns(:entry)
      assert_equal 'sources', assigns(:entry).name
    end

    def test_diff
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [4, '4', 'def6d2f1254a'].each do |r1|
        # Full diff of changeset 4
        ['inline', 'sbs'].each do |dt|
          get :diff, :id => PRJ_ID, :rev => r1, :type => dt
          assert_response :success
          assert_template 'diff'
          if @diff_c_support
            # Line 22 removed
            assert_tag :tag => 'th',
                       :content => '22',
                       :sibling => { :tag => 'td',
                                     :attributes => { :class => /diff_out/ },
                                     :content => /def remove/ }
            assert_tag :tag => 'h2', :content => /4:def6d2f1254a/
          end
        end
      end
    end

    def test_diff_two_revs
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [2, '400bb8672109', '400', 400].each do |r1|
        [4, 'def6d2f1254a'].each do |r2|
          ['inline', 'sbs'].each do |dt|
            get :diff,
                :id     => PRJ_ID,
                :rev    => r1,
                :rev_to => r2,
                :type => dt
            assert_response :success
            assert_template 'diff'
            diff = assigns(:diff)
            assert_not_nil diff
            assert_tag :tag => 'h2',
                       :content => /4:def6d2f1254a 2:400bb8672109/
          end
        end
      end
    end

    def test_diff_latin_1_path
      with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
        [21, 'adf805632193'].each do |r1|
          ['inline', 'sbs'].each do |dt|
            get :diff, :id => PRJ_ID, :rev => r1, :type => dt
            assert_response :success
            assert_template 'diff'
            assert_tag :tag => 'thead',
                       :descendant => {
                         :tag => 'th',
                         :attributes => { :class => 'filename' } ,
                         :content => /latin-1-dir\/test-#{@char_1}-2.txt/ ,
                        },
                       :sibling => {
                         :tag => 'tbody',
                         :descendant => {
                            :tag => 'td',
                            :attributes => { :class => /diff_in/ },
                            :content => /It is written in Python/
                         }
                       }
          end
        end
      end
    end

    def test_annotate
      get :annotate, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
      assert_response :success
      assert_template 'annotate'

      # Line 22, revision 4:def6d2f1254a
      assert_select 'tr' do
        assert_select 'th.line-num', :text => '22'
        assert_select 'td.revision', :text => '4:def6d2f1254a'
        assert_select 'td.author', :text => 'jsmith'
        assert_select 'td', :text => /remove_watcher/
      end
    end

    def test_annotate_not_in_tip
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      get :annotate, :id => PRJ_ID,
          :path => repository_path_hash(['sources', 'welcome_controller.rb'])[:param]
      assert_response 404
      assert_error_tag :content => /was not found/
    end

    def test_annotate_at_given_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      [2, '400bb8672109', '400', 400].each do |r1|
        get :annotate, :id => PRJ_ID, :rev => r1,
            :path => repository_path_hash(['sources', 'watchers_controller.rb'])[:param]
        assert_response :success
        assert_template 'annotate'
        assert_tag :tag => 'h2', :content => /@ 2:400bb8672109/
      end
    end

    def test_annotate_latin_1_path
      [21, '21', 'adf805632193'].each do |r1|
        get :annotate, :id => PRJ_ID,
            :path => repository_path_hash(['latin-1-dir', "test-#{@char_1}-2.txt"])[:param],
            :rev => r1
        assert_response :success
        assert_template 'annotate'
        assert_tag :tag => 'th',
                 :content => '1',
                 :attributes => { :class => 'line-num' },
                 :sibling =>
                       {
                         :tag => 'td',
                         :attributes => { :class => 'revision' },
                         :child => { :tag => 'a', :content => '20:709858aafd1b' }
                       }
        assert_tag :tag => 'th',
                 :content => '1',
                 :attributes => { :class => 'line-num' },
                 :sibling =>
                       {
                          :tag     => 'td'    ,
                          :content => 'jsmith' ,
                          :attributes => { :class   => 'author' },
                        }
        assert_tag :tag => 'th',
                 :content => '1',
                 :attributes => { :class => 'line-num' },
                 :sibling => { :tag => 'td',
                               :content => /Mercurial is a distributed version control system/ }

      end
    end

    def test_annotate_latin_1_contents
      with_settings :repositories_encodings => 'UTF-8,ISO-8859-1' do
        [27, '7bbf4c738e71'].each do |r1|
          get :annotate, :id => PRJ_ID,
              :path => repository_path_hash(['latin-1-dir', "test-#{@char_1}.txt"])[:param],
              :rev => r1
          assert_tag :tag => 'th',
                     :content => '1',
                     :attributes => { :class => 'line-num' },
                     :sibling => { :tag => 'td',
                                   :content => /test-#{@char_1}.txt/ }
        end
      end
    end

    def test_empty_revision
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      @project.reload
      assert_equal NUM_REV, @repository.changesets.count
      ['', ' ', nil].each do |r|
        get :revision, :id => PRJ_ID, :rev => r
        assert_response 404
        assert_error_tag :content => /was not found/
      end
    end

    def test_destroy_valid_repository
      @request.session[:user_id] = 1 # admin
      assert_equal 0, @repository.changesets.count
      @repository.fetch_changesets
      assert_equal NUM_REV, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete :destroy, :id => @repository.id
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end

    def test_destroy_invalid_repository
      @request.session[:user_id] = 1 # admin
      @project.repository.destroy
      @repository = Repository::Mercurial.create!(
                      :project => Project.find(PRJ_ID),
                      :url     => "/invalid",
                      :path_encoding => 'ISO-8859-1'
                      )
      @repository.fetch_changesets
      assert_equal 0, @repository.changesets.count

      assert_difference 'Repository.count', -1 do
        delete :destroy, :id => @repository.id
      end
      assert_response 302
      @project.reload
      assert_nil @project.repository
    end
  else
    puts "Mercurial test repository NOT FOUND. Skipping functional tests !!!"
    def test_fake; assert true end
  end
end
