/**
 * This code needs to be injected in webpage after DOM becomes ready
 * it will re-enable generated code selection on export modal
 */

document.addEventListener('click', () => {

    if (!document.body.innerText.match(/plan to export your site/)) {
        return;
    }

    document.querySelectorAll('code').forEach(element => {
        element.parentElement.style.userSelect = 'all';
    })

});