(function () {
  var mockup = document.getElementById('overlayMockup');
  var apps = mockup.querySelectorAll('.mockup-app');
  var selectedIndex = -1;

  var keys = { 'ArrowRight': true, 'ArrowLeft': true, 'ArrowDown': true, 'ArrowUp': true };

  function selectApp(index) {
    if (index === selectedIndex) return;
    clearSelection();
    if (index >= 0 && index < apps.length) {
      selectedIndex = index;
      apps[index].classList.add('selected');
      mockup.classList.add('active');
    }
  }

  function clearSelection() {
    if (selectedIndex >= 0 && selectedIndex < apps.length) {
      apps[selectedIndex].classList.remove('selected');
    }
    selectedIndex = -1;
    mockup.classList.remove('active');
  }

  function highlightByNum(num) {
    var idx = num === 0 ? 9 : num - 1;
    if (idx >= 0 && idx < apps.length) {
      selectApp(idx);
      setTimeout(clearSelection, 400);
    }
  }

  document.addEventListener('keydown', function (e) {
    if (e.key === 'Meta' && e.location === KeyboardEvent.DOM_KEY_LOCATION_RIGHT) {
      e.preventDefault();
      selectApp(0);
      return;
    }

    if (e.key >= '0' && e.key <= '9') {
      highlightByNum(parseInt(e.key, 10));
      return;
    }

    if (e.key === 'Escape') {
      clearSelection();
      return;
    }

    if (!keys[e.key]) return;

    var cols = 4;
    var rows = Math.ceil(apps.length / cols);
    var row = Math.floor(selectedIndex / cols);
    var col = selectedIndex % cols;

    if (selectedIndex === -1) {
      if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
        e.preventDefault();
        selectApp(0);
      }
      return;
    }

    e.preventDefault();

    if (e.key === 'ArrowRight') col = (col + 1) % cols;
    if (e.key === 'ArrowLeft') col = (col - 1 + cols) % cols;
    if (e.key === 'ArrowDown') row = (row + 1) % rows;
    if (e.key === 'ArrowUp') row = (row - 1 + rows) % rows;

    var newIdx = row * cols + col;
    if (newIdx >= apps.length) newIdx = selectedIndex;
    selectApp(newIdx);
  });

  document.addEventListener('keyup', function (e) {
    if (e.key === 'Meta' && e.location === KeyboardEvent.DOM_KEY_LOCATION_RIGHT) {
      clearSelection();
    }
  });

  mockup.addEventListener('mouseleave', clearSelection);

  apps.forEach(function (app) {
    app.addEventListener('mouseenter', function () {
      var idx = Array.prototype.indexOf.call(apps, app);
      selectApp(idx);
    });
  });

  // Smooth scroll + subtle intersection fade-in
  if ('IntersectionObserver' in window) {
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.style.opacity = '1';
          entry.target.style.transform = 'translateY(0)';
        }
      });
    }, { threshold: 0.15 });

    document.querySelectorAll('.step, .feature, .download-box, .comparison-table').forEach(function (el) {
      el.style.opacity = '0';
      el.style.transform = 'translateY(16px)';
      el.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
      observer.observe(el);
    });
  }
})();
