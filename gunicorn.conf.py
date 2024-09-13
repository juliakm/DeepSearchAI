import multiprocessing

max_requests = 1000
max_requests_jitter = 50
log_file = "-"
bind = "0.0.0.0"

timeout = 230

num_cpus = multiprocessing.cpu_count()
workers = 1  # Keeping single worker due to session issues

# Setting threads to use the maximum based on CPU count, but can adjust this multiplier
threads = num_cpus * 2 

worker_class = "uvicorn.workers.UvicornWorker"
