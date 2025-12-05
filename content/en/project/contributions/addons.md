---
title: Addons
description: "Add your addon to the ecosystem"
weight: 3
---

Have you written an operator or some other automation which integrates with the capsule core project? Feel free to add your addon to the capsule ecosystem overview

## Adding an addon

In the [addons.yaml](https://github.com/projectcapsule/website/blob/main/data/addons.yaml) file you can add an addon to the ecosystem. You just need to add an entry for your addon and upon merging it will automatically be added to our website. To add your organization follow these steps:

1. Fork the [projectcapsule/capsule](https://github.com/projectcapsule/capsule/fork) project to your personal space.
2. Clone it locally with `git clone https://github.com/<YOUR-GH-USERNAME>/capsule.git`.
3.  We prefer using the logo from an upstream resource instead of collecting logos. If you don't have a logo to provide you will get a default logo. 
4.  Open  `docs/data/addons.yaml` following format:
  
    ```yaml
      # Addon Name
    - name: "Example Addon"
      # Link for name
      link: https://www.adopter.net
      # Logo Source
      logo: https://www.adopter.net/wp-content/uploads/logo.svg

      ## Links displayed with icon (Optional)
      links:


    ```
    
    > You can just add to the end of the file, we already sort alphabetically by name of organization.
    
  1. Save the file, then do `git add` -A and commit using `git commit -s -m "chore(docs): add my-addon to addons"` [See our contribution guidelines](/project/contributions/guidelines/).
  2. Push the commit with `git push origin main`.
  3. Open a Pull Request to [projectcapsule/capsule](https://github.com/projectcapsule/capsule/pulls) and a preview build will turn up.
  
  Thanks a lot for being part of our community - we very much appreciate it!
