---
title: Tenants
weight: 4
description: >
  Understand principles and concepts of Capsule Tenants
---
Capsule is a framework to implement multi-tenant and policy-driven scenarios in Kubernetes. In this tutorial, we'll focus on a hypothetical case covering the main features of the Capsule Operator. This documentation is styled in a tutorial format, and it's designed to be read in sequence. We'll start with the basics and then move to more advanced topics.

**Acme Corp**, our sample organization, is building a Container as a Service platform (CaaS) to serve multiple lines of business, or departments, e.g. Oil, Gas, Solar, Wind, Water. Each department has its team of engineers that are responsible for the development, deployment, and operating of their digital products. We'll work with the following actors:

* **Bill**: the cluster administrator from the operations department of Acme Corp.
* **Alice**: the project leader in the Solar & Green departments. She is responsible for a team made of different job responsibilities: e.g. developers, administrators, SRE engineers, etc.
* **Joe**: works as a lead developer of a distributed team in Alice's organization.
* **Bob**: is the head of engineering for the Water department, the main and historical line of business at Acme Corp.

This scenario will guide you through the following topics.