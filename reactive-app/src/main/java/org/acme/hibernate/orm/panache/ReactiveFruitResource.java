package org.acme.hibernate.orm.panache;

import static javax.ws.rs.core.Response.Status.CREATED;

import java.util.List;

import javax.enterprise.context.ApplicationScoped;
import javax.ws.rs.Consumes;
import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.Path;
import javax.ws.rs.Produces;
import javax.ws.rs.WebApplicationException;
import javax.ws.rs.core.Response;

import org.jboss.resteasy.reactive.RestPath;

import io.quarkus.hibernate.reactive.panache.Panache;
import io.quarkus.panache.common.Sort;
import io.smallrye.context.api.CurrentThreadContext;
import io.smallrye.mutiny.Uni;
import org.eclipse.microprofile.context.ThreadContext;

@Path("fruits")
@ApplicationScoped
@Produces("application/json")
@Consumes("application/json")
public class ReactiveFruitResource {

    @GET
    @CurrentThreadContext(propagated = {}, cleared = {}, unchanged = ThreadContext.ALL_REMAINING)
    public Uni<List<Fruit>> get() {
        return Fruit.listAll(Sort.by("name"));
    }


    @GET
    @Path("{id}")
    @CurrentThreadContext(propagated = {}, cleared = {}, unchanged = ThreadContext.ALL_REMAINING)
    public Uni<Fruit> getSingle(@RestPath Long id) {
        return Fruit.findById(id);
    }

    @POST
    @CurrentThreadContext(propagated = {}, cleared = {}, unchanged = ThreadContext.ALL_REMAINING)
    public Uni<Response> create(Fruit fruit) {
        if (fruit == null || fruit.id != null) {
            throw new WebApplicationException("Id was invalidly set on request.", 422);
        }

        return Panache.withTransaction(fruit::persist)
                    .replaceWith(Response.ok(fruit).status(CREATED)::build);
    }

}
