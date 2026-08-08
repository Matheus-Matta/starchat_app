require 'rails_helper'

RSpec.describe Cosmos::Assistant do
  describe '#agent_tools' do
    let(:account) { create(:account) }
    let(:assistant) { create(:cosmos_assistant, account: account) }

    it 'includes enabled custom tools from the assistant account' do
      custom_tool = create(:cosmos_custom_tool, account: account)

      tools = assistant.send(:agent_tools)

      expect(tools.map(&:name)).to include(custom_tool.slug)
      expect(tools.find { |tool| tool.name == custom_tool.slug }).to be_a(Cosmos::Tools::HttpTool)
    end

    it 'excludes disabled custom tools' do
      custom_tool = create(:cosmos_custom_tool, :disabled, account: account)

      tools = assistant.send(:agent_tools)

      expect(tools.map(&:name)).not_to include(custom_tool.slug)
    end

    it 'excludes custom tools from other accounts' do
      custom_tool = create(:cosmos_custom_tool)

      tools = assistant.send(:agent_tools)

      expect(tools.map(&:name)).not_to include(custom_tool.slug)
    end

    it 'keeps the built-in FAQ lookup and handoff tools' do
      tools = assistant.send(:agent_tools)

      expect(tools).to include(
        an_instance_of(Cosmos::Tools::FaqLookupTool),
        an_instance_of(Cosmos::Tools::HandoffTool)
      )
    end
  end
end
