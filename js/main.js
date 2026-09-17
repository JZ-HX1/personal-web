/* ============ 页面交互逻辑 ============ */

// ---- 导航栏滚动效果 ----
const navbar = document.getElementById("navbar");
window.addEventListener("scroll", () => {
  navbar.classList.toggle("scrolled", window.scrollY > 20);
});

// ---- 移动端菜单 ----
const navToggle = document.getElementById("nav-toggle");
const navMenu = document.getElementById("nav-menu");
navToggle.addEventListener("click", () => navMenu.classList.toggle("open"));
navMenu.querySelectorAll("a").forEach((a) =>
  a.addEventListener("click", () => navMenu.classList.remove("open"))
);

// ---- 导航高亮当前板块 ----
const sections = document.querySelectorAll("section[id]");
const navLinks = document.querySelectorAll(".nav-link");
window.addEventListener("scroll", () => {
  let current = "";
  sections.forEach((s) => {
    if (window.scrollY >= s.offsetTop - 120) current = s.id;
  });
  navLinks.forEach((link) => {
    link.classList.toggle("active", link.getAttribute("href") === "#" + current);
  });
});

// ---- 渲染技能 ----
const skillsGrid = document.getElementById("skills-grid");
skillsGrid.innerHTML = SKILLS.map(
  (s) => `
  <div class="skill-card">
    <div class="skill-head">
      <span class="skill-name">${s.name}</span>
      <span class="skill-pct">${s.level}%</span>
    </div>
    <div class="skill-bar">
      <div class="skill-bar-fill" data-level="${s.level}"></div>
    </div>
    <div class="skill-tags">
      ${s.tags.map((t) => `<span class="skill-tag">${t}</span>`).join("")}
    </div>
  </div>`
).join("");

// 技能条进入视口后再展开动画
const skillObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.style.width = entry.target.dataset.level + "%";
        skillObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.4 }
);
document.querySelectorAll(".skill-bar-fill").forEach((el) => skillObserver.observe(el));

// ---- 证书弹窗 ----
const certModal = document.getElementById("cert-modal");
document.getElementById("cert-view-btn").addEventListener("click", () => {
  certModal.classList.add("open");
});
document.getElementById("modal-close").addEventListener("click", () => {
  certModal.classList.remove("open");
});
certModal.addEventListener("click", (e) => {
  if (e.target === certModal) certModal.classList.remove("open");
});
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") certModal.classList.remove("open");
});

// ---- 渲染项目 ----
const projectsGrid = document.getElementById("projects-grid");
const filtersBox = document.getElementById("project-filters");

function renderProjects(category) {
  const list =
    category === "全部" ? PROJECTS : PROJECTS.filter((p) => p.category === category);
  if (list.length === 0) {
    projectsGrid.innerHTML = `<p style="text-align:center;color:#5a7184;grid-column:1/-1;">该分类下暂无项目</p>`;
    return;
  }
  projectsGrid.innerHTML = list
    .map(
      (p) => `
    <article class="project-card">
      <div class="project-cover">
        ${p.icon}
        <span class="project-year">${p.year}</span>
      </div>
      <div class="project-body">
        <h3 class="project-title">${p.title}</h3>
        <p class="project-desc">${p.desc}</p>
        <div class="project-tags">
          ${p.tags.map((t) => `<span class="project-tag">${t}</span>`).join("")}
        </div>
        ${
          p.links
            ? `<div class="project-links"><a href="${p.links.url}" target="_blank" rel="noopener">${p.links.text} →</a></div>`
            : ""
        }
      </div>
    </article>`
    )
    .join("");
}

function renderFilters() {
  filtersBox.innerHTML = PROJECT_CATEGORIES.map(
    (c, i) =>
      `<button class="filter-btn ${i === 0 ? "active" : ""}" data-cat="${c}">${c}</button>`
  ).join("");
  filtersBox.querySelectorAll(".filter-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      filtersBox
        .querySelectorAll(".filter-btn")
        .forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      renderProjects(btn.dataset.cat);
    });
  });
}

renderFilters();
renderProjects("全部");
