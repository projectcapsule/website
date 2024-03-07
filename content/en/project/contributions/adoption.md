---
title: Adoption
description: "Add your project/company to the list of adopters"
weight: 2
---

Have your tried Capsule or are you using it in your project or company? Please consider adding your project/company to the list of adopters. This helps the Capsule community understand who is using Capsule and how it is being used.

## Adding yourself

In the [adopters.yaml](https://github.com/projectcapsule/website/blob/main/data/adopters.yaml) file you can add yourself as an adopter of the project. You just need to add an entry for your company and upon merging it will automatically be added to our website. To add your organization follow these steps:

1. Fork the [projectcapsule/website](https://github.com/projectcapsule/website/fork) project to your personal space.
2. Clone it locally with `git clone https://github.com/<YOUR-GH-USERNAME>/website.git`.
3.  We prefer using the logo from an upstream resource instead of collecting logos. If you don't have a logo to provide you will get a default logo. 
4.  Open  `data/adopters.yaml` file and add your organization to the list. The file is in the following format:
  
    ```yaml
      # Company/Project Name
    - name: "Adopter Name"
      # Link for name
      link: https://www.adopter.net
      # Logo Source
      logo: https://www.adopter.net/wp-content/uploads/logo.svg
    ```
    
    > You can just add to the end of the file, we already sort alphabetically by name of organization.
    
  5. Save the file, then do `git add` -A and commit using `git commit -s -m "Add MY-ORG to adopters"` [See our contribution guidelines](/project/contributions/guidelines/).
  6. Push the commit with `git push origin main`.
  7. Open a Pull Request to [capsule/website](https://github.com/projectcapsule/website/pulls) and a preview build will turn up.
  
  Thanks a lot for being part of our community - we very much appreciate it!




