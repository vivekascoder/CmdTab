(function () {
  if (window.Plyr) {
    new Plyr('#player', {
      controls: ['play-large', 'play', 'progress', 'current-time', 'mute', 'volume', 'fullscreen']
    });
  }

  var menu = document.querySelector('.mobile-menu');
  var menuButton = document.querySelector('.nav-menu-button');
  var closeButton = document.querySelector('.mobile-menu-close');
  var menuLinks = document.querySelectorAll('.mobile-menu a');

  function setMenuOpen(isOpen) {
    if (!menu || !menuButton) return;

    menu.classList.toggle('is-open', isOpen);
    document.body.classList.toggle('menu-open', isOpen);
    menu.setAttribute('aria-hidden', isOpen ? 'false' : 'true');
    menuButton.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
  }

  if (menu && menuButton) {
    menuButton.addEventListener('click', function () {
      setMenuOpen(true);
    });

    if (closeButton) {
      closeButton.addEventListener('click', function () {
        setMenuOpen(false);
      });
    }

    menu.addEventListener('click', function (event) {
      if (event.target === menu) {
        setMenuOpen(false);
      }
    });

    menuLinks.forEach(function (link) {
      link.addEventListener('click', function () {
        setMenuOpen(false);
      });
    });

    document.addEventListener('keydown', function (event) {
      if (event.key === 'Escape') {
        setMenuOpen(false);
      }
    });
  }

  if (!('IntersectionObserver' in window)) return;

  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.style.opacity = '1';
        entry.target.style.transform = 'translateY(0)';
      }
    });
  }, { threshold: 0.15 });

  document.querySelectorAll('.demo-player, .step, .download-box, .comparison-table').forEach(function (el) {
    el.style.opacity = '0';
    el.style.transform = 'translateY(16px)';
    el.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
    observer.observe(el);
  });
})();
