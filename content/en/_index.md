---
title: Project Capsule
# The hero renders the navbar inside the page content (see home/viewport), and
# docsy's navbar builds the offline search index. Indexing this page's body
# would re-enter that build and deadlock the render, so keep this page out of
# the index -- it only holds button labels anyway.
exclude_search: true
---

{{< home/viewport >}}
{{< blocks/cover title="Self-service namespaces" image_anchor="top" height="full" >}}

<p class="home-hero__lead">
Capsule is a multi-tenancy framework for Kubernetes. Give teams the freedom to create and manage their own namespaces. Keep access, resource budgets and policies under platform control.
</p>

<div class="home-hero__footer">
<div class="d-flex flex-wrap align-items-center justify-content-center gap-3 mb-4">
<a class="btn btn-lg btn-primary" href="/docs/quickstart/">
  Get started <i class="fas fa-arrow-alt-circle-right ms-2" aria-hidden="true"></i>
</a>

<div class="d-flex gap-3">
<a class="btn btn-lg btn-outline-light" href="https://killercoda.com/projectcapsule/scenario/demo">
  Live demo
</a>

<a class="btn btn-lg btn-outline-light" href="https://github.com/projectcapsule/capsule">
  GitHub <i class="fab fa-github ms-2" aria-hidden="true"></i>
</a>
</div>
</div>

</div>
{{< blocks/link-down color="white" icon="fa-arrow-down" >}}
{{< /blocks/cover >}}
{{< /home/viewport >}}

{{< blocks/section color="white" type="container" >}}
{{< home/story >}}
{{< /blocks/section >}}

{{< blocks/section color="200" type="container" >}}
{{< home/features >}}
{{< /blocks/section >}}

{{< blocks/section color="white" type="container" >}}
{{< home/ecosystem >}}
{{< /blocks/section >}}

{{< blocks/section color="200" type="container" >}}
{{< home/alternatives >}}
{{< /blocks/section >}}

{{< blocks/section color="white" type="container-fluid" >}}
{{< home/adopters >}}
{{< /blocks/section >}}

{{< blocks/section color="200" type="container" >}}
{{< home/cta >}}
{{< /blocks/section >}}
