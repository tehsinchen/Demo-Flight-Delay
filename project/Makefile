CLUSTER_NAME ?= dev
K3D ?= k3d

cluster_create:
	$(K3D) cluster create $(CLUSTER_NAME)

cluster_delete:
	$(K3D) cluster delete $(CLUSTER_NAME)

cluster_start:
	$(K3D) cluster start $(CLUSTER_NAME)

cluster_stop:
	$(K3D) cluster stop $(CLUSTER_NAME)

image_import:
	$(K3D) image import frontend:latest backend:latest crawler:latest -c $(CLUSTER_NAME)

serving:
	kubectl -n kube-system port-forward svc/traefik 8080:80

dev:
	kubectl apply -k k8s/overlays/dev

prod:
	kubectl apply -k k8s/overlays/prod

.PHONY: cluster_create cluster_delete cluster_start cluster_stop image_import serving dev prod
