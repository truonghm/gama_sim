/**
* Name: sheperd
* Based on the internal skeleton template. 
* Author: truonghm
* Tags: 
*/

model sheperd

global {
	
	float step <- 1 #month;
	string scenario <- "all_respectful";
	bool is_batch <- false;
	
	bool has_no_regulation <- false;
	int width <- 50;
	int height <- 50;
	int n_sheperds <- 10;
	int n_goats_per_sheperd <- 10;
	float goat_eating_cap <- 0.7;
	int eating_season_month_end <- 10;
	int n_months_to_full_growth <- 50;
	float min_seed_take_root_proba <- 0.0025;
	int max_fringe_size <- 8;
	int min_fringe_size <- 4;
	float tree_init_cover <- 0.3;
	int goat_move_range <- 5;
	float threshold_to_eat <- 0.05; // this is to make sure the goats can move when the amount of tree available is very close to 0
	
	int n_respectful_sheperd <- 10;
	int n_disrespectful_sheperd <- n_sheperds - n_respectful_sheperd;

	init {
		int n <- 0;
		loop i over: 1 to n_sheperds {
		    
		    if has_no_regulation {
		    	rgb goat_color <- #purple;
		    	image_file goat_icon <- image_file("../includes/neutral_goat.png");
		    	create goat number: n_goats_per_sheperd with: [color:: goat_color, icon:: goat_icon] returns: goats_per_sheperd;
		    	create sheperd with: [herd_color:: goat_color, goats:: goats_per_sheperd, is_respectful:: true];
		    } else {
			    if n < n_respectful_sheperd {
			    	rgb goat_color <- #blue;
			    	image_file goat_icon <- image_file("../includes/respectful_goat.png");
			    	create goat number: n_goats_per_sheperd with: [color:: goat_color, icon:: goat_icon] returns: goats_per_sheperd;
			    	create sheperd with: [herd_color:: goat_color, goats:: goats_per_sheperd, is_respectful:: true];
			    } else {
			    	rgb goat_color <- #red;
			    	image_file goat_icon <- image_file("../includes/disrespectful_goat.png");
			    	create goat number: n_goats_per_sheperd with: [color:: goat_color, icon:: goat_icon] returns: goats_per_sheperd;
			    	create sheperd with: [herd_color:: #red, goats:: goats_per_sheperd, is_respectful:: false];
			    }
		    }
		    
		    n <- n + 1;
		}
	}

	float global_min_size <- sheperd mean_of (each.min_size) update: sheperd mean_of (each.min_size);
	float avg_grove_size <- pasture_cell mean_of (each.current_size)update: pasture_cell mean_of (each.current_size);
	float tree_cov <- ((pasture_cell count (each.tree = 1)) / (width * height))update: ((pasture_cell count (each.tree = 1)) / (width * height));
	
	reflex save_result when: !is_batch {
			save [
				int(self),
				tree_cov, 
				n_respectful_sheperd, 
				n_disrespectful_sheperd, 
				global_min_size,
				avg_grove_size,
				current_date.month,
				current_date.year
			] 
		   		to: "results_" + scenario + ".csv" format:"csv" rewrite: (cycle = 0) ? true : false header: true;
	}

	reflex stop_simulation when: (time > 720#month) or (tree_cov = 0.0) or (tree_cov > 0.99) and !is_batch {
		do pause;
	} 
}

grid pasture_cell height: height width: width neighbors: max_fringe_size {

	float max_tree <- 1.0;
	float growth_rate <- max_tree / n_months_to_full_growth;
//	float tree max: max_tree update: tree + growth_rate;
	float tree max: max_tree;
	float current_size;
	rgb color <- rgb(int(144 * (1 - tree)), int(238 - 138 * tree), int(144 * (1 - tree))) update: rgb(int(144 * (1 - tree)), int(238 - 138 * tree), int(144 * (1 - tree)));
	bool has_tree <- flip(tree_init_cover);
	list<pasture_cell> neighbors_to_move  <- (self neighbors_at goat_move_range);
	list<pasture_cell> fringe <- (self neighbors_at max_fringe_size);

	init {
		if has_tree {
			tree <- 1.0;
			color <- rgb(0, 100, 0); // full-grown tree to eat
		} else {
			tree <- 0.0;
			color <- rgb(144, 238, 144); // only grass available to eat
		}
	}
	
	reflex grow_tree when: every (1 #month) {
			tree <- tree + growth_rate;
			current_size <- tree / growth_rate;
	}

	reflex plant_seed when: tree = 0 and every (1 #month) {
		int nb_tree_count <- fringe count (each.tree = 1.0);
		if nb_tree_count >= min_fringe_size {
			has_tree <- flip(min_seed_take_root_proba * nb_tree_count);
		}
	}
}

species sheperd {
	int min_size <- 0;
	rgb herd_color;
	list<goat> goats;
	bool is_respectful;
	list<int> unique_months <- [];

	init {
		loop g over: goats {
			g.is_respectful <- is_respectful;
		}
	}
	
	reflex check_month when: every (1#month) {
		loop g over: goats {
			if g.unique_months contains current_date.month {
				add current_date.month to: unique_months;
				break;
			}
		}
	}
	reflex compute_min_size when: current_date.month = 1 {
		min_size <- eating_season_month_end - length(unique_months);
		unique_months <- [];
		loop g over: goats {
			g.herd_min_size <- min_size;
		}
	}
}

species goat {
    rgb color;
    bool is_respectful;
    int herd_min_size <- 0;
	list<int> unique_months <- [];
	pasture_cell my_cell <- one_of (pasture_cell) ;
	float eating_cap <- goat_eating_cap;
	image_file icon;

    init {
		location <- my_cell.location;
    }

	reflex reset when: current_date.month = 1 {
		unique_months <- [];
	}
	
	action move {
		my_cell <- one_of (my_cell.neighbors_to_move) ;
		location <- my_cell.location ;
	}
    reflex move when: (my_cell.tree <= threshold_to_eat) and current_date.month <= eating_season_month_end {
		if has_no_regulation {
			do move;
		} else {
			if not is_respectful {
				if my_cell.current_size < herd_min_size {
					do move;
				}
			} else {
				if my_cell.current_size < global_min_size {
					do move;
				}
			}
		}
    }
    
    action eat_tree {
		my_cell.tree <- my_cell.tree - min([eating_cap, my_cell.tree]);
		if my_cell.tree = 0.0 {
			my_cell.has_tree <- false;
		}
    }
    
    reflex check_month when: every (1#month) {
		if not (unique_months contains current_date.month) {
			add current_date.month to: unique_months;
		}
    }

	reflex eat_tree when: my_cell.tree > threshold_to_eat and current_date.month <= eating_season_month_end { 
		if has_no_regulation {
			do eat_tree;
		} else {
			if not is_respectful {
				if my_cell.current_size >= herd_min_size {
					do eat_tree;
				}
			} else {
				if my_cell.current_size >= global_min_size {
					do eat_tree;
				}
			}
		}
		
	}

    aspect default {
        draw circle(0.8) color: color;
    }
    
    aspect use_icon {
    	draw icon color: color size:3;
    }
}

experiment sheperd_exp type: gui {
	
	parameter "Scenario alias: " var: scenario category: "Initialization";
	parameter "Eating season - Month end: " var: eating_season_month_end category: "Initialization";
	parameter "Initial grove coverage: " var: tree_init_cover category: "Initialization" min: 0.0 max: 1.0 step: 0.1 slider: true;
	
	parameter "Disable regulation completely: " var: has_no_regulation category: "Sheperd and goat";
	parameter "Number of goat per herd: " var: n_goats_per_sheperd category: "Sheperd and goat";
	parameter "Grazing Capacity of goat: " var: goat_eating_cap category: "Sheperd and goat" min: 0.0 max: 1.0 step: 0.1 slider: true;
	parameter "Goat perceive/move range: " var: goat_move_range category: "Sheperd and goat";
	parameter "Number of respectful sheperds: " var: n_respectful_sheperd category: "Sheperd and goat" min: 0 max: n_sheperds step: 1 slider: true;

	parameter "Number of months for tree groves to fully grow" var: n_months_to_full_growth category: "Tree groves" step: 5 slider: true;
	parameter "Minimum probability to spread seed: " var: min_seed_take_root_proba category: "Tree groves" min: 0.0 max: 1.0;
	parameter "Fringe/Neighbor size: " var: max_fringe_size category: "Tree groves" ;
	parameter "Minimum fringe size for seed to spread: " var: min_fringe_size category: "Tree groves" ;

	output {
		monitor "Current month" value: current_date.month;
		monitor "Current year" value: current_date.year;
		
		display grid {
			grid pasture_cell;
			species goat aspect: use_icon;
			
		}

		display charts refresh: every (12 #month) {
			chart "Average grove size vs Institutional minimum size" type:series background:rgb(255,255,255) {
				data "avg min size" legend: "Ins. min size" value: global_min_size color:#green marker: false style: line;
				data "avg grove size" legend: "Avg grove size" value: avg_grove_size color: #red marker: false style: line;
			}

			chart "Grove coverage (fully grown only) at the beginning of grazing season" type:series  background:rgb(255,255,255) {
				data "grove cov fully grow" value: tree_cov color:#red marker: false style: line;
			}
		}
		
		display charts refresh: every (1 #month) {
			chart "Grove coverage (fully grown only) through time" x_tick_unit: 12 type:series  background:rgb(255,255,255) {
				data "grove cov fully grow" value: tree_cov color:#red marker: false style: line;
			}
		}
	}
}

experiment optimize type: batch repeat: 2 keep_seed: true until: time > 5#year {
	parameter "Grazing Capacity of goat: " var: goat_eating_cap category: "Sheperd and goat" min: 0.1 max: 1.0 step: 0.1;
	parameter "Minimum probability to spread seed: " var: min_seed_take_root_proba category: "Tree groves" min: 0.0005 max: 0.125 step: 0.0005;
	parameter "Number of respectful sheperds: " var: n_respectful_sheperd category: "Sheperd and goat" min: 0 max: n_sheperds step: 1 slider: true;
	parameter "Batch mode:" var: is_batch <- true;
	
    method tabu 
        iter_max: 10 tabu_list_size: 3 
        minimize: abs(tree_cov - 0.6);

	reflex save_results_explo {
		ask simulations {
			save [
				int(self),
				tree_cov,
				global_min_size,
				avg_grove_size,
				n_respectful_sheperd, 
				n_disrespectful_sheperd, 
				goat_eating_cap,
				min_seed_take_root_proba,
				current_date.month,
				current_date.year
			] 
		   		to: "optim.csv" format:"csv" rewrite: (int(self) = 0) ? true : false header: true;
		}		
	}
}
