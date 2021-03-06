require 'spec_helper'

describe "User pages" do

  subject { page }

  describe "profile page" do
    let(:user) { FactoryGirl.create(:user) }
    let(:other_user) { FactoryGirl.create(:user) }

    it "should display profile if you're logged in" do
      sign_in(other_user)
      visit user_path(user)
      page.should have_heading user.fullname
      page.should have_title user.fullname
    end

    it "should display profile if you're logged out" do
      visit user_path(user)
      page.should have_heading user.fullname
      page.should have_title user.fullname
    end
  end

  describe "signup page" do
    before { visit signup_path }

    it { should have_heading 'Join SciRate' }
    it { should have_title 'Join SciRate' }
  end

  describe "signup" do

    before { visit signup_path }

    describe "with invalid information" do
      it "should not create a user" do
        expect { signup }.not_to change(User, :count)
      end
    end

    describe "error messages" do
      before { signup }

      it { should have_title 'Join SciRate' }
      it { should have_error_message }
    end

    describe "with valid information" do
      it "should create a user" do
        expect { valid_signup }.to change(User, :count).by(1)
      end

      describe "after saving the user" do
        before { valid_signup(email: 'test-new@example.com') }
        let(:user) { User.find_by_email('test-new@example.com') }

        it { should have_title "" }
        it { should have_content 'Welcome to SciRate!' }
        it { should have_content user.email }
      end
    end

    describe "account confirmation" do
      describe "emails user on signup" do
        before do
          visit signup_path
          valid_signup(email: 'test-new@example.com')
        end

        let(:user) { User.find_by_email('test-new@example.com') }

        it { should have_title "Home feed" }
        it { should have_content(user.email) }
        it { should have_content "You can find feeds to subscribe to" }

        it "should send the email" do
          last_email.to.should include(user.email)
        end
      end

      describe "does not email on invalid signup" do
        before do
          visit signup_path
          signup
        end

        it "should not send email" do
          last_email.should be_nil
        end
      end

      describe "activation" do
        let(:user) { FactoryGirl.create(:user,
                                        active: false,
                                        confirmation_token: "i-am-a-token",
                                        confirmation_sent_at: 2.hours.ago) }

        describe "with valid information" do
          describe "it should give the correct response" do
            before { visit activate_user_path(user.id, user.confirmation_token) }

            it { should have_title "" }
            it { should have_content("Your account has been activated") }
          end

          it "it should activate the user" do
            expect do
              visit activate_user_path(user.id, user.confirmation_token)
              user.reload
            end.to change(user, :active).to(true)
          end
        end

        describe "with invalid confirmation" do
          describe "it should give the an error message" do
            before { visit activate_user_path(user.id, "bogus") }

            it { should have_title "" }
            it { should have_content("link is invalid") }
          end

          it "it should not activate the user" do
            expect do
              visit activate_user_path(user.id, "bogus")
              user.reload
            end.not_to change(user, :active).to(true)
          end
        end

        describe "with expired confirmation" do
          before do
            user.confirmation_sent_at = 3.days.ago
            user.save!
          end

          describe "should give an error message" do
            before { visit activate_user_path(user.id, user.confirmation_token) }

            it { should have_content("link has expired") }
            it { should have_content("email has been sent") }

            it "should send the email" do
              user_updated = User.find_by_email!(user.email)
              last_email.to.should include(user_updated.email)
              last_email.body.should include(user_updated.confirmation_token)
            end
          end

          it "it should not activate the user" do
            expect do
              visit activate_user_path(user.id, user.confirmation_token)
              user.reload
            end.not_to change(user, :active).to(true)
          end
        end

        describe "with already used confirmation" do
          before do
            visit activate_user_path(user.id, user.confirmation_token)
            visit activate_user_path(user.id, user.confirmation_token)
          end

          it { should have_title "" }
          it { should have_content("link is invalid") }
        end

        describe "for an active user" do
          before do
            user.active = true
            user.save!
            visit activate_user_path(user.id, user.confirmation_token)
          end

          it { should have_title "" }
          it { should have_content("link is invalid") }
        end
      end
    end
  end

  describe "settings" do
    let(:user) { FactoryGirl.create(:user) }
    before do
      sign_in user
      visit settings_path
    end

    it "shouldn't allow use of reserved usernames" do
      fill_in "Username", with: "arxiv"
      click_button "Save changes"

      page.should have_error_message "Username is already taken"
    end

    describe "page" do
      it { should have_link('change', href: 'http://gravatar.com/emails') }

      describe "fields" do
        it { should have_field "Name", with: user.fullname }
        it { should have_field "Email", with: user.email }
      end
    end

    describe "with valid information" do
      let(:new_name)  { "New Name" }
      let(:new_email) { "new@example.com" }

      before do
        fill_in "Name",         with: new_name
        fill_in "Email",        with: new_email
        click_button "Save changes"
      end

      it { should have_selector('.alert-success') }
      specify { user.reload.fullname.should  == new_name }
      specify { user.reload.email.should == new_email }
    end

    describe "email confirmation of address changes" do
      let(:new_name) { "New User" }
      let(:new_email) { "new@example.com" }

      describe "with new email address" do
        before do
          fill_in "Email", with: new_email
          click_button "Save changes"
        end

        it "should send email to old address" do
          last_email.should_not be_nil
          last_email.to.should include(user.email)
        end
      end

      describe "without new email address" do
        before do
          fill_in "Name", with: new_name
          click_button "Save changes"
        end

        it "should not send email" do
          last_email.should be_nil
        end
      end
    end
  end
end
