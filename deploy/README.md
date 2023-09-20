# Filter for each from varibales lists

```bash
  for_each =  {for key, val in var.kubeadm_nodes:
               key => val if val.role == "master-member"}
```
