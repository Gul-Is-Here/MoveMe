// Progressive enhancements for MoveMe's legal pages. Everything here is
// optional — without JS the pages render fully, just without motion.
(function () {
  var root = document.documentElement;
  root.classList.add('js');

  var reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // Reading progress bar + back-to-top button.
  var bar = document.querySelector('.progress');
  var toTop = document.querySelector('.to-top');
  var ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(function () {
      var max = root.scrollHeight - root.clientHeight;
      var y = root.scrollTop || document.body.scrollTop;
      if (bar) bar.style.transform = 'scaleX(' + (max > 0 ? y / max : 0) + ')';
      if (toTop) toTop.classList.toggle('show', y > 600);
      ticking = false;
    });
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
  if (toTop) {
    toTop.addEventListener('click', function () {
      window.scrollTo({ top: 0, behavior: reduceMotion ? 'auto' : 'smooth' });
    });
  }

  document.querySelectorAll('.copy[data-copy]').forEach(function (btn) {
    if (!navigator.clipboard) { btn.remove(); return; }
    var label = btn.querySelector('span');
    var value = btn.parentNode.querySelector('.mail-value');
    function flash(text) {
      btn.classList.add('done');
      label.textContent = text;
      setTimeout(function () { btn.classList.remove('done'); label.textContent = 'Copy'; }, 1800);
    }
    btn.addEventListener('click', function () {
      navigator.clipboard.writeText(btn.getAttribute('data-copy')).then(function () {
        flash('Copied');
      }, function () {
        // Clipboard refused: select the address so it can be copied manually.
        var range = document.createRange();
        range.selectNodeContents(value);
        var sel = window.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
        flash('Selected');
      });
    });
  });

  if (!('IntersectionObserver' in window)) {
    document.querySelectorAll('.reveal').forEach(function (el) { el.classList.add('in'); });
    return;
  }

  // Fade sections up as they scroll into view.
  var revealer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add('in');
        revealer.unobserve(entry.target);
      }
    });
  }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
  document.querySelectorAll('.reveal').forEach(function (el) { revealer.observe(el); });

  // Highlight the table-of-contents entry for the section being read.
  var links = Array.prototype.slice.call(document.querySelectorAll('.toc a[href^="#"]'));
  if (!links.length) return;
  var byId = {};
  links.forEach(function (a) { byId[a.getAttribute('href').slice(1)] = a; });
  var visible = {};
  var spy = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) { visible[entry.target.id] = entry.isIntersecting; });
    var current = null;
    for (var i = 0; i < links.length; i++) {
      var id = links[i].getAttribute('href').slice(1);
      if (visible[id]) { current = id; break; }
    }
    if (!current) return;
    links.forEach(function (a) { a.classList.remove('active'); a.removeAttribute('aria-current'); });
    byId[current].classList.add('active');
    byId[current].setAttribute('aria-current', 'true');
  }, { rootMargin: '-90px 0px -55% 0px' });
  Object.keys(byId).forEach(function (id) {
    var section = document.getElementById(id);
    if (section) spy.observe(section);
  });
})();
