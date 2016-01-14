#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Daniel DeLeo (<dan@opscode.com>)
# Copyright:: Copyright (c) 2008, 2010, 2013 Opscode, Inc.
#
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

shared_examples_for "a useradd-based user provider" do |supported_useradd_options|
  before(:each) do
    @node = Chef::Node.new
    @events = Chef::EventDispatch::Dispatcher.new
    @run_context = Chef::RunContext.new(@node, {}, @events)

    @new_resource = Chef::Resource::User.new("adam", @run_context)
    @new_resource.comment "Adam Jacob"
    @new_resource.uid 1000
    @new_resource.gid 1000
    @new_resource.home "/home/adam"
    @new_resource.shell "/usr/bin/zsh"
    @new_resource.password "abracadabra"
    @new_resource.system false
    @new_resource.manage_home false
    @new_resource.force false
    @new_resource.non_unique false
    @current_resource = Chef::Resource::User.new("adam", @run_context)
    @current_resource.comment "Adam Jacob"
    @current_resource.uid 1000
    @current_resource.gid 1000
    @current_resource.home "/home/adam"
    @current_resource.shell "/usr/bin/zsh"
    @current_resource.password "abracadabra"
    @current_resource.system false
    @current_resource.manage_home false
    @current_resource.force false
    @current_resource.non_unique false
    @current_resource.supports({:manage_home => false, :non_unique => false})
  end

  describe "when setting option" do

    supported_useradd_options.each do |attribute, option|
      it "should check for differences in #{attribute} between the new and current resources" do
        expect(@current_resource).to receive(attribute)
        expect(@new_resource).to receive(attribute)
        provider.universal_options
      end

      it "should set the option for #{attribute} if the new resources #{attribute} is not nil" do
        allow(@new_resource).to receive(attribute).and_return("hola")
        expect(provider.universal_options).to eql([option, 'hola'])
      end

      it "should set the option for #{attribute} if the new resources #{attribute} is not nil, without homedir management" do
        allow(@new_resource).to receive(:supports).and_return({:manage_home => false,
                                                    :non_unique => false})
        allow(@new_resource).to receive(attribute).and_return("hola")
        expect(provider.universal_options).to eql([option, 'hola'])
      end

      it "should set the option for #{attribute} if the new resources #{attribute} is not nil, without homedir management (using real attributes)" do
        allow(@new_resource).to receive(:manage_home).and_return(false)
        allow(@new_resource).to receive(:non_unique).and_return(false)
        allow(@new_resource).to receive(:non_unique).and_return(false)
        allow(@new_resource).to receive(attribute).and_return("hola")
        expect(provider.universal_options).to eql([option, 'hola'])
      end
    end

    it "should combine all the possible options" do
      combined_opts = []
      supported_useradd_options.sort{ |a,b| a[0] <=> b[0] }.each do |attribute, option|
        allow(@new_resource).to receive(attribute).and_return("hola")
        combined_opts << option << 'hola'
      end
      expect(provider.universal_options).to eql(combined_opts)
    end

    describe "when we want to create a system user" do
      before do
        @new_resource.manage_home(true)
        @new_resource.non_unique(false)
      end

      it "should set useradd -r" do
        @new_resource.system(true)
        expect(provider.useradd_options).to eq([ "-r" ])
      end
    end

    describe "when the resource has a different home directory and supports home directory management" do
      before do
        allow(@new_resource).to receive(:home).and_return("/wowaweea")
        allow(@new_resource).to receive(:supports).and_return({:manage_home => true,
                                                   :non_unique => false})
      end

      it "should set -m -d /homedir" do
        expect(provider.universal_options).to eq(%w[-d /wowaweea -m])
        expect(provider.useradd_options).to eq([])
      end
    end

    describe "when the resource has a different home directory and supports home directory management (using real attributes)" do
      before do
        allow(@new_resource).to receive(:home).and_return("/wowaweea")
        allow(@new_resource).to receive(:manage_home).and_return(true)
        allow(@new_resource).to receive(:non_unique).and_return(false)
      end

      it "should set -m -d /homedir" do
        expect(provider.universal_options).to eql(%w[-d /wowaweea -m])
        expect(provider.useradd_options).to eq([])
      end
    end

    describe "when the resource supports non_unique ids" do
      before do
        allow(@new_resource).to receive(:supports).and_return({:manage_home => false,
                                                  :non_unique => true})
      end

      it "should set -m -o" do
        expect(provider.universal_options).to eql([ "-o" ])
      end
    end

    describe "when the resource supports non_unique ids (using real attributes)" do
      before do
        allow(@new_resource).to receive(:manage_home).and_return(false)
        allow(@new_resource).to receive(:non_unique).and_return(true)
      end

      it "should set -m -o" do
        expect(provider.universal_options).to eql([ "-o" ])
      end
    end
  end

  describe "when creating a user" do
    before(:each) do
      @current_resource = Chef::Resource::User.new(@new_resource.name, @run_context)
      @current_resource.username(@new_resource.username)
      provider.current_resource = @current_resource
      provider.new_resource.manage_home true
      provider.new_resource.home "/Users/mud"
      provider.new_resource.gid '23'
    end

    it "runs useradd with the computed command options" do
      command = ["useradd",
                  "-c",  'Adam Jacob',
                  "-g", '23' ]
      command.concat(["-p", 'abracadabra']) if supported_useradd_options.key?("password")
      command.concat([ "-s", '/usr/bin/zsh',
                       "-u", '1000',
                       "-d", '/Users/mud',
                       "-m",
                       "adam" ])
      expect(provider).to receive(:shell_out!).with(*command).and_return(true)
      provider.create_user
    end

    describe "and home is not specified for new system user resource" do

      before do
        provider.new_resource.system true
        # there is no public API to set attribute's value to nil
        provider.new_resource.instance_variable_set("@home", nil)
      end

      it "should not include -m or -d in the command options" do
        command = ["useradd",
                    "-c", 'Adam Jacob',
                    "-g", '23']
        command.concat(["-p", 'abracadabra']) if supported_useradd_options.key?("password")
        command.concat([ "-s", '/usr/bin/zsh',
                         "-u", '1000',
                         "-r",
                         "adam" ])
        expect(provider).to receive(:shell_out!).with(*command).and_return(true)
        provider.create_user
      end

    end

  end

  describe "when managing a user" do
    before(:each) do
      provider.new_resource.manage_home true
      provider.new_resource.home "/Users/mud"
      provider.new_resource.gid '23'
    end

    # CHEF-3423, -m must come before the username
    # CHEF-4305, -d must come before -m to support CentOS/RHEL 5
    it "runs usermod with the computed command options" do
      command = ["usermod",
                  "-g", '23',
                  "-d", '/Users/mud',
                  "-m",
                  "adam" ]
      expect(provider).to receive(:shell_out!).with(*command).and_return(true)
      provider.manage_user
    end

    it "does not set the -r option to usermod" do
      @new_resource.system(true)
      command = ["usermod",
                  "-g", '23',
                  "-d", '/Users/mud',
                  "-m",
                  "adam" ]
      expect(provider).to receive(:shell_out!).with(*command).and_return(true)
      provider.manage_user
    end

    it "CHEF-3429: does not set -m if we aren't changing the home directory" do
      expect(provider).to receive(:updating_home?).and_return(false)
      command = ["usermod",
                  "-g", '23',
                  "adam" ]
      expect(provider).to receive(:shell_out!).with(*command).and_return(true)
      provider.manage_user
    end
  end

  describe "when removing a user" do

    it "should run userdel with the new resources user name" do
      expect(provider).to receive(:shell_out!).with("userdel", @new_resource.username).and_return(true)
      provider.remove_user
    end

    it "should run userdel with the new resources user name and -r if manage_home is true" do
      @new_resource.supports({ :manage_home => true,
                               :non_unique => false})
      expect(provider).to receive(:shell_out!).with("userdel", "-r", @new_resource.username).and_return(true)
      provider.remove_user
    end

    it "should run userdel with the new resources user name if non_unique is true" do
      @new_resource.supports({ :manage_home => false,
                               :non_unique => true})
      expect(provider).to receive(:shell_out!).with("userdel", @new_resource.username).and_return(true)
      provider.remove_user
    end

    it "should run userdel with the new resources user name and -f if force is true" do
      @new_resource.force(true)
      expect(provider).to receive(:shell_out!).with("userdel", "-f", @new_resource.username).and_return(true)
      provider.remove_user
    end
  end

  describe "when checking the lock" do
    # lazy initialize so we can modify stdout and stderr strings
    let(:passwd_s_status) do
      double("Mixlib::ShellOut command", :exitstatus => 0, :stdout => @stdout, :stderr => @stderr)
    end

    before(:each) do
      # @node = Chef::Node.new
      # @new_resource = double("Chef::Resource::User",
      #   :nil_object => true,
      #   :username => "adam"
      # )
      #provider = Chef::Provider::User::Useradd.new(@node, @new_resource)
      @stdout = "root P 09/02/2008 0 99999 7 -1"
      @stderr = ""
    end

    it "should return false if status begins with P" do
      expect(provider).to receive(:shell_out!).
        with("passwd", "-S", @new_resource.username, {:returns=>[0, 1]}).
        and_return(passwd_s_status)
      expect(provider.check_lock).to eql(false)
    end

    it "should return false if status begins with N" do
      @stdout = "root N"
      expect(provider).to receive(:shell_out!).
        with("passwd", "-S", @new_resource.username, {:returns=>[0, 1]}).
        and_return(passwd_s_status)
      expect(provider.check_lock).to eql(false)
    end

    it "should return true if status begins with L" do
      @stdout = "root L"
      expect(provider).to receive(:shell_out!).
        with("passwd", "-S", @new_resource.username, {:returns=>[0, 1]}).
        and_return(passwd_s_status)
      expect(provider.check_lock).to eql(true)
    end

    it "should raise a Chef::Exceptions::User if passwd -S fails on anything other than redhat/centos" do
      @node.automatic_attrs[:platform] = 'ubuntu'
      expect(provider).to receive(:shell_out!).
        with("passwd", "-S", @new_resource.username, {:returns=>[0, 1]}).
        and_return(passwd_s_status)
      expect(passwd_s_status).to receive(:exitstatus).and_return(1)
      expect { provider.check_lock }.to raise_error(Chef::Exceptions::User)
    end

    ['redhat', 'centos'].each do |os|
      it "should not raise a Chef::Exceptions::User if passwd -S exits with 1 on #{os} and the passwd package is version 0.73-1" do
        @node.automatic_attrs[:platform] = os
        expect(passwd_s_status).to receive(:exitstatus).and_return(1)
        expect(provider).to receive(:shell_out!).
          with("passwd", "-S", @new_resource.username, {:returns=>[0, 1]}).
          and_return(passwd_s_status)
        rpm_status = double("Mixlib::ShellOut command", :exitstatus => 0, :stdout => "passwd-0.73-1\n", :stderr => "")
        expect(provider).to receive(:shell_out!).with("rpm -q passwd").and_return(rpm_status)
        expect { provider.check_lock }.not_to raise_error
      end

      it "should raise a Chef::Exceptions::User if passwd -S exits with 1 on #{os} and the passwd package is not version 0.73-1" do
        @node.automatic_attrs[:platform] = os
        expect(passwd_s_status).to receive(:exitstatus).and_return(1)
        expect(provider).to receive(:shell_out!).
          with("passwd", "-S", @new_resource.username, {:returns=>[0, 1]}).
          and_return(passwd_s_status)
        rpm_status = double("Mixlib::ShellOut command", :exitstatus => 0, :stdout => "passwd-0.73-2\n", :stderr => "")
        expect(provider).to receive(:shell_out!).with("rpm -q passwd").and_return(rpm_status)
        expect { provider.check_lock }.to raise_error(Chef::Exceptions::User)
      end

      it "should raise a ShellCommandFailed exception if passwd -S exits with something other than 0 or 1 on #{os}" do
        @node.automatic_attrs[:platform] = os
        expect(provider).to receive(:shell_out!).and_raise(Mixlib::ShellOut::ShellCommandFailed)
        expect { provider.check_lock }.to raise_error(Mixlib::ShellOut::ShellCommandFailed)
      end
    end

    context "when in why run mode" do
      before do
        passwd_status = double("Mixlib::ShellOut command", :exitstatus => 0, :stdout => "", :stderr => "passwd: user 'chef-test' does not exist\n")
        expect(provider).to receive(:shell_out!).
          with("passwd", "-S", @new_resource.username, {:returns=>[0, 1]}).
          and_return(passwd_status)
        Chef::Config[:why_run] = true
      end

      it "should return false if the user does not exist" do
        expect(provider.check_lock).to eql(false)
      end

      it "should not raise an error if the user does not exist" do
        expect { provider.check_lock }.not_to raise_error
      end
    end
  end

  describe "when locking the user" do
    it "should run usermod -L with the new resources username" do
      expect(provider).to receive(:shell_out!).with("usermod", "-L", @new_resource.username)
      provider.lock_user
    end
  end

  describe "when unlocking the user" do
    it "should run usermod -L with the new resources username" do
      expect(provider).to receive(:shell_out!).with("usermod", "-U", @new_resource.username)
      provider.unlock_user
    end
  end

  describe "when checking if home needs updating" do
    [
     {
       "action" => "should return false if home matches",
       "current_resource_home" => [ "/home/laurent" ],
       "new_resource_home" => [ "/home/laurent" ],
       "expected_result" => false,
     },
     {
       "action" => "should return true if home doesn't match",
       "current_resource_home" => [ "/home/laurent" ],
       "new_resource_home" => [ "/something/else" ],
       "expected_result" => true,
     },
     {
       "action" => "should return false if home only differs by trailing slash",
       "current_resource_home" => [ "/home/laurent" ],
       "new_resource_home" => [ "/home/laurent/", "/home/laurent" ],
       "expected_result" => false,
     },
     {
       "action" => "should return false if home is an equivalent path",
       "current_resource_home" => [ "/home/laurent" ],
       "new_resource_home" => [ "/home/./laurent", "/home/laurent" ],
       "expected_result" => false,
     },
    ].each do |home_check|
      it home_check["action"] do
        provider.current_resource.home home_check["current_resource_home"].first
        @current_home_mock = double("Pathname")
        provider.new_resource.home home_check["new_resource_home"].first
        @new_home_mock = double("Pathname")

        expect(Pathname).to receive(:new).with(@current_resource.home).and_return(@current_home_mock)
        expect(@current_home_mock).to receive(:cleanpath).and_return(home_check["current_resource_home"].last)
        expect(Pathname).to receive(:new).with(@new_resource.home).and_return(@new_home_mock)
        expect(@new_home_mock).to receive(:cleanpath).and_return(home_check["new_resource_home"].last)

        expect(provider.updating_home?).to eq(home_check["expected_result"])
      end
    end
    it "should return true if the current home does not exist but a home is specified by the new resource" do
      @new_resource = Chef::Resource::User.new("adam", @run_context)
      @current_resource = Chef::Resource::User.new("adam", @run_context)
      provider = Chef::Provider::User::Useradd.new(@new_resource, @run_context)
      provider.current_resource = @current_resource
      @current_resource.home nil
      @new_resource.home "/home/kitten"

      expect(provider.updating_home?).to eq(true)
    end
  end
end

