require 'spec_helper'

describe MergeRequests::CreateService do
  let(:project) { create(:project, :repository) }
  let(:user) { create(:user) }
  let(:assignee) { create(:user) }

  describe '#execute' do
    context 'valid params' do
      let(:opts) do
        {
          title: 'Awesome merge_request',
          description: 'please fix',
          source_branch: 'feature',
          target_branch: 'master',
          force_remove_source_branch: '1'
        }
      end

      let(:service) { described_class.new(project, user, opts) }
      let(:merge_request) { service.execute }

      before do
        project.team << [user, :master]
        project.team << [assignee, :developer]
        allow(service).to receive(:execute_hooks)
      end

      it 'creates an MR' do
        expect(merge_request).to be_valid
        expect(merge_request.title).to eq('Awesome merge_request')
        expect(merge_request.assignee).to be_nil
        expect(merge_request.merge_params['force_remove_source_branch']).to eq('1')
      end

      it 'executes hooks with default action' do
        expect(service).to have_received(:execute_hooks).with(merge_request)
      end

      it 'refreshes the number of open merge requests' do
        expect { service.execute }
          .to change { project.open_merge_requests_count }.from(0).to(1)
      end

      it 'does not creates todos' do
        attributes = {
          project: project,
          target_id: merge_request.id,
          target_type: merge_request.class.name
        }

        expect(Todo.where(attributes).count).to be_zero
      end

      it 'creates exactly 1 create MR event' do
        attributes = {
          action: Event::CREATED,
          target_id: merge_request.id,
          target_type: merge_request.class.name
        }

        expect(Event.where(attributes).count).to eq(1)
      end

      context 'when merge request is assigned to someone' do
        let(:opts) do
          {
            title: 'Awesome merge_request',
            description: 'please fix',
            source_branch: 'feature',
            target_branch: 'master',
            assignee: assignee
          }
        end

        it { expect(merge_request.assignee).to eq assignee }

        it 'creates a todo for new assignee' do
          attributes = {
            project: project,
            author: user,
            user: assignee,
            target_id: merge_request.id,
            target_type: merge_request.class.name,
            action: Todo::ASSIGNED,
            state: :pending
          }

          expect(Todo.where(attributes).count).to eq 1
        end
      end

      context 'when head pipelines already exist for merge request source branch' do
        let(:sha) { project.commit(opts[:source_branch]).id }
        let!(:pipeline_1) { create(:ci_pipeline, project: project, ref: opts[:source_branch], project_id: project.id, sha: sha) }
        let!(:pipeline_2) { create(:ci_pipeline, project: project, ref: opts[:source_branch], project_id: project.id, sha: sha) }
        let!(:pipeline_3) { create(:ci_pipeline, project: project, ref: "other_branch", project_id: project.id) }

        before do
          project.merge_requests
            .where(source_branch: opts[:source_branch], target_branch: opts[:target_branch])
            .destroy_all
        end

        it 'sets head pipeline' do
          merge_request = service.execute

          expect(merge_request.head_pipeline).to eq(pipeline_2)
          expect(merge_request).to be_persisted
        end

        context 'when merge request head commit sha does not match pipeline sha' do
          it 'sets the head pipeline correctly' do
            pipeline_2.update(sha: 1234)

            merge_request = service.execute

            expect(merge_request.head_pipeline).to eq(pipeline_1)
            expect(merge_request).to be_persisted
          end
        end
      end
    end

    it_behaves_like 'new issuable record that supports quick actions' do
      let(:default_params) do
        {
          source_branch: 'feature',
          target_branch: 'master'
        }
      end
    end

    context 'Quick actions' do
      context 'with assignee and milestone in params and command' do
        let(:merge_request) { described_class.new(project, user, opts).execute }
        let(:milestone) { create(:milestone, project: project) }

        let(:opts) do
          {
            assignee_id: create(:user).id,
            milestone_id: 1,
            title: 'Title',
            description: %(/assign @#{assignee.username}\n/milestone %"#{milestone.name}"),
            source_branch: 'feature',
            target_branch: 'master'
          }
        end

        before do
          project.team << [user, :master]
          project.team << [assignee, :master]
        end

        it 'assigns and sets milestone to issuable from command' do
          expect(merge_request).to be_persisted
          expect(merge_request.assignee).to eq(assignee)
          expect(merge_request.milestone).to eq(milestone)
        end
      end
    end

    context 'merge request create service' do
      context 'asssignee_id' do
        let(:assignee) { create(:user) }

        before do
          project.team << [user, :master]
        end

        it 'removes assignee_id when user id is invalid' do
          opts = { title: 'Title', description: 'Description', assignee_id: -1 }

          merge_request = described_class.new(project, user, opts).execute

          expect(merge_request.assignee_id).to be_nil
        end

        it 'removes assignee_id when user id is 0' do
          opts = { title: 'Title', description: 'Description',  assignee_id: 0 }

          merge_request = described_class.new(project, user, opts).execute

          expect(merge_request.assignee_id).to be_nil
        end

        it 'saves assignee when user id is valid' do
          project.team << [assignee, :master]
          opts = { title: 'Title', description: 'Description', assignee_id: assignee.id }

          merge_request = described_class.new(project, user, opts).execute

          expect(merge_request.assignee).to eq(assignee)
        end

        context 'when assignee is set' do
          let(:opts) do
            {
              title: 'Title',
              description: 'Description',
              assignee_id: assignee.id,
              source_branch: 'feature',
              target_branch: 'master'
            }
          end

          it 'invalidates open merge request counter for assignees when merge request is assigned' do
            project.team << [assignee, :master]

            described_class.new(project, user, opts).execute

            expect(assignee.assigned_open_merge_requests_count).to eq 1
          end
        end

        context "when issuable feature is private" do
          before do
            project.project_feature.update(issues_access_level: ProjectFeature::PRIVATE,
                                           merge_requests_access_level: ProjectFeature::PRIVATE)
          end

          levels = [Gitlab::VisibilityLevel::INTERNAL, Gitlab::VisibilityLevel::PUBLIC]

          levels.each do |level|
            it "removes not authorized assignee when project is #{Gitlab::VisibilityLevel.level_name(level)}" do
              project.update(visibility_level: level)
              opts = { title: 'Title', description: 'Description', assignee_id: assignee.id }

              merge_request = described_class.new(project, user, opts).execute

              expect(merge_request.assignee_id).to be_nil
            end
          end
        end
      end
    end

    context 'while saving references to issues that the created merge request closes' do
      let(:first_issue) { create(:issue, project: project) }
      let(:second_issue) { create(:issue, project: project) }

      let(:opts) do
        {
          title: 'Awesome merge_request',
          source_branch: 'feature',
          target_branch: 'master',
          force_remove_source_branch: '1'
        }
      end

      before do
        project.team << [user, :master]
        project.team << [assignee, :developer]
      end

      it 'creates a `MergeRequestsClosingIssues` record for each issue' do
        issue_closing_opts = opts.merge(description: "Closes #{first_issue.to_reference} and #{second_issue.to_reference}")
        service = described_class.new(project, user, issue_closing_opts)
        allow(service).to receive(:execute_hooks)
        merge_request = service.execute

        issue_ids = MergeRequestsClosingIssues.where(merge_request: merge_request).pluck(:issue_id)
        expect(issue_ids).to match_array([first_issue.id, second_issue.id])
      end
    end
  end
end
