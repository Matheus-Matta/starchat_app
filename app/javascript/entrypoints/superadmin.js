import '../dashboard/assets/scss/super_admin/index.scss';

const selectAllAccountFeatures = event => {
  const container = event.currentTarget.closest('[data-account-features]');
  const uncheckedFeatures = Array.from(
    container.querySelectorAll('input[type="checkbox"]:not(:checked)')
  );

  uncheckedFeatures.forEach(checkbox => checkbox.click());
};

document.addEventListener('DOMContentLoaded', () => {
  document
    .querySelectorAll('[data-select-all-account-features]')
    .forEach(button =>
      button.addEventListener('click', selectAllAccountFeatures)
    );
});
