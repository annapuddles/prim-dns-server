window.addEventListener('load', function() {
    document.querySelectorAll('.color-button').forEach(btn => btn.addEventListener('click', function() {
        document.getElementById('color-text').style.color = btn.getAttribute('data-color');
    }));
});
