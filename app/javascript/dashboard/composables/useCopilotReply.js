import { ref, computed } from 'vue';

export function useCopilotReply() {
  const showEditor = ref(false);
  const isGenerating = ref(false);
  const isContentReady = ref(false);
  const generatedContent = ref('');

  const isActive = computed(() => showEditor.value || isGenerating.value);
  const isButtonDisabled = computed(
    () => isGenerating.value || !isContentReady.value
  );
  const editorTransitionKey = computed(() =>
    isActive.value ? 'copilot' : 'rich'
  );

  function reset() {
    showEditor.value = false;
    isGenerating.value = false;
    isContentReady.value = false;
    generatedContent.value = '';
  }

  function toggleEditor() {
    showEditor.value = !showEditor.value;
  }

  function setContentReady() {
    isContentReady.value = true;
  }

  // eslint-disable-next-line no-unused-vars
  async function execute(_action, _data) {}

  // eslint-disable-next-line no-unused-vars
  async function sendFollowUp(_message) {}

  function accept() {
    const content = generatedContent.value;
    reset();
    return content;
  }

  return {
    showEditor,
    isGenerating,
    isContentReady,
    generatedContent,
    isActive,
    isButtonDisabled,
    editorTransitionKey,
    reset,
    toggleEditor,
    setContentReady,
    execute,
    sendFollowUp,
    accept,
  };
}
