require 'spec_helper'

describe Gitlab::API do
  include ApiHelpers

  let(:user) { Factory :user }
  let(:user2) { Factory.create(:user) }
  let(:user3) { Factory.create(:user) }
  let!(:project) { Factory :project, owner: user }
  let!(:snippet) { Factory :snippet, author: user, project: project, title: 'example' }
  let!(:users_project) { Factory :users_project, user: user, project: project }
  before { project.add_access(user, :read) }

  describe "GET /projects" do
    it "should return authentication error" do
      get api("/projects")
      response.status.should == 401
    end

    describe "authenticated GET /projects" do
      it "should return an array of projects" do
        get api("/projects", user)
        response.status.should == 200
        json_response.should be_an Array
        json_response.first['name'].should == project.name
        json_response.first['owner']['email'].should == user.email
      end
    end
  end

  describe "POST /projects" do
    it "should create new project without code and path" do
      expect { post api("/projects", user), name: 'foo' }.to change {Project.count}.by(1)
    end

    it "should not create new project without name" do
      expect { post api("/projects", user) }.to_not change {Project.count}
    end

    it "should respond with 201 on success" do
      post api("/projects", user), name: 'foo'
      response.status.should == 201
    end

    it "should repsond with 404 on failure" do
      post api("/projects", user)
      response.status.should == 404
    end

    it "should assign attributes to project" do
      project = Factory.attributes(:project, {
        path: 'path',
        code: 'code',
        description: Faker::Lorem.sentence,
        default_branch: 'stable',
        issues_enabled: false,
        wall_enabled: false,
        merge_requests_enabled: false,
        wiki_enabled: false
      })

      post api("/projects", user), project

      project.each_pair do |k,v|
        json_response[k.to_s].should == v
      end
    end
  end

  describe "GET /projects/:id" do
    it "should return a project by id" do
      get api("/projects/#{project.id}", user)
      response.status.should == 200
      json_response['name'].should == project.name
      json_response['owner']['email'].should == user.email
    end

    it "should return a project by code name" do
      get api("/projects/#{project.code}", user)
      response.status.should == 200
      json_response['name'].should == project.name
    end

    it "should return a 404 error if not found" do
      get api("/projects/42", user)
      response.status.should == 404
      json_response['message'].should == '404 Not found'
    end
  end

  describe "GET /projects/:id/repository/branches" do
    it "should return an array of project branches" do
      get api("/projects/#{project.code}/repository/branches", user)
      response.status.should == 200
      json_response.should be_an Array
      json_response.first['name'].should == project.repo.heads.sort_by(&:name).first.name
    end
  end

  describe "GET /projects/:id/repository/branches/:branch" do
    it "should return the branch information for a single branch" do
      get api("/projects/#{project.code}/repository/branches/new_design", user)
      response.status.should == 200

      json_response['name'].should == 'new_design'
      json_response['commit']['id'].should == '621491c677087aa243f165eab467bfdfbee00be1'
    end
  end

  describe "POST /projects/:id/users" do
    it "should add users to project" do
      expect {
        post api("/projects/#{project.code}/users", user),
          user_ids: {"0" => user2.id, "1" => user3.id}, project_access: UsersProject::DEVELOPER
      }.to change {project.users_projects.where(:project_access => UsersProject::DEVELOPER).count}.by(2)
    end
  end

  describe "PUT /projects/:id/users" do
    it "should update users to new access role" do
      expect {
        put api("/projects/#{project.code}/users", user),
          user_ids: {"0" => user}, project_access: UsersProject::DEVELOPER
      }.to change {project.users_projects.where(:project_access => UsersProject::DEVELOPER).count}.by(1)
    end
  end

  describe "DELETE /projects/:id/users" do
    it "should delete users from project" do
      expect {
        delete api("/projects/#{project.code}/users", user),
          user_ids: {"0" => users_project.id}
      }.to change {project.users_projects.where(:project_access => UsersProject::DEVELOPER).count}.by(-1)
    end
  end

  describe "GET /projects/:id/repository/tags" do
    it "should return an array of project tags" do
      get api("/projects/#{project.code}/repository/tags", user)
      response.status.should == 200
      json_response.should be_an Array
      json_response.first['name'].should == project.repo.tags.sort_by(&:name).reverse.first.name
    end
  end

  describe "GET /projects/:id/snippets/:snippet_id" do
    it "should return a project snippet" do
      get api("/projects/#{project.code}/snippets/#{snippet.id}", user)
      response.status.should == 200
      json_response['title'].should == snippet.title
    end
  end

  describe "POST /projects/:id/snippets" do
    it "should create a new project snippet" do
      post api("/projects/#{project.code}/snippets", user),
        title: 'api test', file_name: 'sample.rb', code: 'test'
      response.status.should == 201
      json_response['title'].should == 'api test'
    end
  end

  describe "PUT /projects/:id/snippets" do
    it "should update an existing project snippet" do
      put api("/projects/#{project.code}/snippets/#{snippet.id}", user),
        code: 'updated code'
      response.status.should == 200
      json_response['title'].should == 'example'
      snippet.reload.content.should == 'updated code'
    end
  end

  describe "DELETE /projects/:id/snippets/:snippet_id" do
    it "should delete existing project snippet" do
      expect {
        delete api("/projects/#{project.code}/snippets/#{snippet.id}", user)
      }.to change { Snippet.count }.by(-1)
    end
  end

  describe "GET /projects/:id/snippets/:snippet_id/raw" do
    it "should get a raw project snippet" do
      get api("/projects/#{project.code}/snippets/#{snippet.id}/raw", user)
      response.status.should == 200
    end
  end

  describe "GET /projects/:id/:sha/blob" do
    it "should get the raw file contents" do
      get api("/projects/#{project.code}/repository/commits/master/blob?filepath=README.md", user)
      response.status.should == 200
    end

    it "should return 404 for invalid branch_name" do
      get api("/projects/#{project.code}/repository/commits/invalid_branch_name/blob?filepath=README.md", user)
      response.status.should == 404
    end

    it "should return 404 for invalid file" do
      get api("/projects/#{project.code}/repository/commits/master/blob?filepath=README.invalid", user)
      response.status.should == 404
    end
  end
end
