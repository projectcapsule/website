---
title: CNCF Security Slam 2023
date: 2024-02-01
description: >
  CNCF Security Slam 2023
tags:
  - event
---

Starting in [this dicussion](https://github.com/projectcapsule/capsule/discussions/820) it peaked our interested. Especially seeing which end users seem to have submitted response for our project. So we started working towards a 100% score on the CNCF Security Slam 2023 and were rewarded for our work with this patch:


![CNCF Slam 2023 Award](/images/blog/security-slam-2023/award-capsule.jpg)

🦄 Notable changes regarding Supply Chain security we have done during the CNCF Security Slam:

- Release Helm charts in OCI format
- Implement Docker Image publication with [ko.build](https://ko.build/)
- Signed Releases, SBOMs
- Provide Attestation for published artifacts (SLSA Level 3)

Read how artifacts can be verified here:
https://lnkd.in/eUJvR7YP

If you would like to use signed images with ko or publish helm charts in OCI format, we have templates for that:
https://lnkd.in/ePgMJhRN

In the end we were able to achieve a 100% score on the CNCF Security Slam 2023. And were awarded four badges (beside being the second project to overall achieve a [100% score in CLOMonitor](https://clomonitor.io/projects/cncf/capsule)):

Sadly none of of the maintainers were able to attend the KubeCon+CloudNativeCon NA 2023. But our good friend [Fabio Pasetti](https://www.linkedin.com/in/fabio-pasetti/) was there and accepted the award on our behalf from [Eddie Night](https://www.linkedin.com/in/knight1776/):

![CNCF Slam 2023 Receiver](/images/blog/security-slam-2023/receiver.jpg)

We are looking forward to the next Security Slam and are trying to improve our projects security continuously. 
