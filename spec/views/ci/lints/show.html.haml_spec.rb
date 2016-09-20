require 'spec_helper'

describe 'ci/lints/show' do
  let(:content) do
    {
      build_template: {
        script: './build.sh',
        tags: ['dotnet'],
        only: ['test@dude/repo'],
        except: ['deploy'],
        environment: 'testing'
      }
    }
  end

  let(:config_processor) { Ci::GitlabCiYamlProcessor.new(YAML.dump(content)) }

  context 'when the content is valid' do
    before do
      assign(:status, true)
      assign(:builds, config_processor.builds)
      assign(:stages, config_processor.stages)
      assign(:jobs, config_processor.jobs)
    end

    it 'shows the correct values' do
      render

      expect(rendered).to have_content('Tag list: dotnet')
      expect(rendered).to have_content('Refs only: test@dude/repo')
      expect(rendered).to have_content('Refs except: deploy')
      expect(rendered).to have_content('Environment: testing')
      expect(rendered).to have_content('When: on_success')
    end
  end

  context 'when the content is invalid' do
    before do
      assign(:status, false)
      assign(:error, 'Undefined error')
    end

    it 'shows error message' do
      render

      expect(rendered).to have_content('Status: syntax is incorrec')
      expect(rendered).to have_content('Error: Undefined error')
      expect(rendered).not_to have_content('Tag list:')
    end
  end
end
